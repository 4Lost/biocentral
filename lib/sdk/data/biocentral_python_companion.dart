import 'dart:convert';

import 'package:bio_flutter/bio_flutter.dart';
import 'package:biocentral/sdk/biocentral_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:serious_python/serious_python.dart';

abstract class _BiocentralPythonCompanionUtils {
  static Future<Either<BiocentralPythonCompanionException, Map<String, Embedding>>> _readEmbeddingsFromResponse(
    Map<String, dynamic>? id2emb,
    String embedderName,
  ) async {
    if (id2emb == null) {
      return left(
        BiocentralPythonCompanionException(
            message: 'Parsing of embeddings failed - Could not convert result map from companion!'),
      );
    }

    final Map<String, Embedding> result = {};
    for (final entry in id2emb.entries) {
      final conversion = _fromList(entry.value, embedderName);
      if (conversion == null) {
        return left(
          BiocentralPythonCompanionException(message: 'Parsing of embeddings failed - could not create embedding!'),
        );
      }
      result[entry.key] = conversion;
    }
    return right(result);
  }

  static Embedding? _fromList(List<dynamic> embd, String embedderName) {
    if (embd.first is List) {
      final List<List<double>> convertedEmbedding = embd.map<List<double>>((innerList) {
        return (innerList as List).cast<double>();
      }).toList();

      return PerResidueEmbedding(convertedEmbedding, embedderName: embedderName);
    }
    if (embd.first is double) {
      return PerSequenceEmbedding(embd.cast<double>(), embedderName: embedderName);
    }
    return null;
  }
}

abstract class _BiocentralPythonCompanionStrategy {
  bool _companionReady = false;

  Future<Either<BiocentralException, Map<String, Embedding>>> loadH5File(Uint8List bytes, String embedderName);

  Future<Either<BiocentralException, String>> writeH5File(Map<String, Embedding> embeddings);

  Future<Either<BiocentralException, List<dynamic>>> testDistributions(List<double> data, String types);
  
  Future<void> startCompanion();

  Future<bool> healthCheck();

  Future<bool> _checkCompanionRunning() async {
    if (_companionReady) {
      return true;
    }
    final int maxRetries = 120;
    for (int retry = 0; retry < maxRetries; retry++) {
      try {
        final companionHealthCheck = await healthCheck();
        if (companionHealthCheck) {
          return true;
        } else {
          // Companion app not ready yet, wait and try again
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return false;
  }

  Future<Either<BiocentralException, T>> _intercept<T>(
      Future<Either<BiocentralException, T>> Function() operation) async {
    final companionRunning = await _checkCompanionRunning();
    if (!companionRunning) {
      return left(
        BiocentralNetworkException(
          message: 'Could not reach python companion after max retries. Please restart the application and try again!',
        ),
      );
    }
    _companionReady = true;
    return operation();
  }

  Future<bool> terminate();
}

class _BiocentralPythonCompanionDesktopStrategy extends _BiocentralPythonCompanionStrategy with HTTPClient {
  @override
  Either<BiocentralException, String> getBaseURL() {
    return right('http://127.0.0.1:50001/');
  }

  @override
  Future<Either<BiocentralException, Map<String, Embedding>>> loadH5File(Uint8List bytes, String embedderName) async {
    final Map<String, String> body = {'h5_bytes': base64Encode(bytes)};
    final responseEither = await doPostRequest('read_h5', body);
    return responseEither.match((l) async {
      return left(l);
    }, (r) async {
      Future<Either<BiocentralPythonCompanionException, Map<String, Embedding>>> readFunction(dynamic _) {
        return _BiocentralPythonCompanionUtils._readEmbeddingsFromResponse(
          (r['id2emb'] ?? {}) as Map<String, dynamic>,
          embedderName,
        );
      }

      final embeddings = await compute(readFunction, null);

      return embeddings;
    });
  }

  @override
  Future<Either<BiocentralException, String>> writeH5File(Map<String, Embedding> embeddings) async {
    final Map<String, String> body = {
      'embeddings': jsonEncode(embeddings.map((key, embd) => MapEntry(key, embd.rawValues()))),
    };
    final responseEither = await doPostRequest('write_h5', body);
    return responseEither.match((l) async {
      return left(l);
    }, (r) async {
      final h5Bytes = r['h5_bytes'];
      return right(h5Bytes);
    });
  }

  @override
  Future<Either<BiocentralException, List<dynamic>>> testDistributions(List<double> data, String types) async {
    final Map<String, String> body = {
      'data': jsonEncode(data),
      'types': jsonEncode(types)
    };
    final responseEither = await doPostRequest('test_distributions', body);
    return responseEither.match(
      (l) => left(l),
      (r) {
      final List<String> list = ['dist_type', 'is_dist', 'p_value', 'statistic'];
      final result = r.entries.map((entrie) {
        return Map<String, dynamic>.fromIterables(list, entrie.value);
      }).toList();
      return right(result);
    });
  }

  @override
  Future<void> startCompanion() async {
    SeriousPython.run(
      'assets/python_companion.zip',
      appFileName: 'python_companion_desktop.py',
    );
  }

  @override
  Future<bool> healthCheck() async {
    final response = await super.doGetRequest('health_check');
    if (response.isRight()) {
      return true;
    }
    return false;
  }

  @override
  Future<bool> terminate() async {
    await super.doGetRequest('terminate');
    return true;
  }

  @override
  Future<Either<BiocentralException, Map>> doGetRequest(String endpoint) async {
    return super._intercept<Map>(() => super.doGetRequest(endpoint));
  }

  @override
  Future<Either<BiocentralException, Map>> doPostRequest(String endpoint, Map<String, String> body) {
    return super._intercept<Map>(() => super.doPostRequest(endpoint, body));
  }

  @override
  Future<Either<BiocentralException, String>> doSimpleFileDownload(String url) {
    return super._intercept<String>(() => super.doSimpleFileDownload(url));
  }
}

class _BiocentralPythonCompanionWebStrategy extends _BiocentralPythonCompanionStrategy {
  @override
  Future<Either<BiocentralException, List<dynamic>>> testDistributions(List<double> data, String types) async {
    final String? result = await runPythonCommand(
      environmentVariables: {
        'PYODIDE_COMMAND': 'test_distributions',
        'PYODIDE_DATA': jsonEncode({'data': data, 'types': types})
      },
    );
    if (result == null || result.isEmpty) {
      return left(BiocentralPythonCompanionException(message: 'Could not load embeddings via python companion!'));
    }
    final decodedResult = jsonDecode(result);
    return right(decodedResult);
  }

  @override
  Future<Either<BiocentralException, Map<String, Embedding>>> loadH5File(Uint8List bytes, String embedderName) async {
    final String? result = await runPythonCommand(
      environmentVariables: {
        'PYODIDE_COMMAND': 'read_h5',
        'PYODIDE_DATA': jsonEncode({'h5_bytes': base64Encode(bytes)}),
      },
    );
    if (result == null || result.isEmpty) {
      return left(
        BiocentralPythonCompanionException(
            message: 'Could not load embeddings for $embedderName'
                ' via python companion!',
                ),
      );
    }
    final decodedResult = jsonDecode(result);

    Future<Either<BiocentralPythonCompanionException, Map<String, Embedding>>> readFunction(dynamic _) {
      return _BiocentralPythonCompanionUtils._readEmbeddingsFromResponse(
        (decodedResult['id2emb'] ?? {}) as Map<String, dynamic>,
        embedderName,
      );
    }

    final embeddings = await compute(readFunction, null);

    return embeddings;
  }

  @override
  Future<Either<BiocentralException, String>> writeH5File(Map<String, Embedding> embeddings) async {
    final String? result = await runPythonCommand(
      environmentVariables: {
        'PYODIDE_COMMAND': 'read_h5',
        'PYODIDE_DATA':
            jsonEncode({'embeddings': jsonEncode(embeddings.map((key, embd) => MapEntry(key, embd.rawValues())))}),
      },
    );
    if (result == null || result.isEmpty) {
      return left(BiocentralPythonCompanionException(message: 'Could not load embeddings via python companion!'));
    }
    final decodedResult = jsonDecode(result);
    return decodedResult;
  }

  @override
  Future<void> startCompanion() async {
    SeriousPython.run(
      'assets/python_companion.zip',
      appFileName: 'python_companion_web.py',
      modulePaths: ['python_companion/web', 'python_companion/functionality'],
      environmentVariables: {'PYODIDE_COMMAND': 'setup', 'PYODIDE_DATA': ''},
    ).then(
      (_) => _companionReady = true,
      onError: (_) => _companionReady = false,
    );
  }

  Future<String?> runPythonCommand({required Map<String, String>? environmentVariables}) async {
    Future<Either<BiocentralException, String?>> eitherWrapper() async {
      final result = await SeriousPython.run(
        'assets/python_companion.zip',
        appFileName: 'python_companion_web.py',
        modulePaths: [
          'python_companion/web',
          'python_companion/functionality',
        ],
        environmentVariables: environmentVariables,
      );
      if (result == null) {
        return left(BiocentralPythonCompanionException(message: 'Error running pyodide python companion'));
      }
      return right(result);
    }

    final eitherResult = await super._intercept<String?>(eitherWrapper);
    final result = eitherResult.getRight().getOrElse(() => '');
    return result;
  }

  @override
  Future<bool> healthCheck() async {
    return _companionReady;
  }

  @override
  Future<bool> terminate() async {
    _companionReady = false;
    return true; // Nothing to do
  }
}

class BiocentralPythonCompanion {
  final _BiocentralPythonCompanionStrategy _strategy;

  BiocentralPythonCompanion._internal(this._strategy);

  static Future<BiocentralPythonCompanion> startCompanion() async {
    // TODO Error handling / maybe downloading of asset
    _BiocentralPythonCompanionStrategy strategy;
    if (kIsWeb) {
      strategy = _BiocentralPythonCompanionWebStrategy();
    } else {
      strategy = _BiocentralPythonCompanionDesktopStrategy();
    }

    final companion = BiocentralPythonCompanion._internal(strategy);
    final companionAlreadyRunning = await strategy.healthCheck();
    if (!companionAlreadyRunning) {
      strategy.startCompanion();
    }
    return companion;
  }

  Future<bool> terminate() async {
    return _strategy.terminate();
  }

  Future<Either<BiocentralException, Map<String, Embedding>>> loadH5File(Uint8List bytes, String embedderName) {
    return _strategy.loadH5File(bytes, embedderName);
  }

  Future<Either<BiocentralException, String>> writeH5File(Map<String, Embedding> embeddings) {
    return _strategy.writeH5File(embeddings);
  }

  Future<Either<BiocentralException, List<dynamic>>> testDistributions(List<double> data, String types) {
    return _strategy.testDistributions(data, types);
  }
}
