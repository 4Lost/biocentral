import json
import functionality

_command_functions = {
    "setup": lambda _: "Success",
    "test_distributions": lambda data, types: functionality.test_distributions(data,types),
    "read_h5": lambda data: functionality.read_h5(data),
    "write_h5": lambda data: functionality.write_h5(data)
}


def handle_command(command: str, data):
    command_function = _command_functions.get(command)
    try:
        parsed_json = json.loads(data)
        loaded_data = parsed_json.get('data')
    except json.decoder.JSONDecodeError:
        loaded_data = data
    if command == "test_distributions":
        try:
            loaded_types = parsed_json.get('types')
        except json.decoder.JSONDecodeError:
            loaded_types = ''
        return command_function(loaded_data, loaded_types)
    else:
        return command_function(loaded_data)
