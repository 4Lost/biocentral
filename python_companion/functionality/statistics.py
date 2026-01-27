import json
import math
import numpy as np
from scipy import stats


def test_distributions(json_data, distributions):
    results = []
    for distribution in distributions:
        results.append(dist_tester(json_data, distribution))
    return {"results": results}


def dist_tester(json_data, distribution):
    data = json_data

    if not data:
        return {"error": "No data provided"}

    if isinstance(data, str):
        data = json.loads(data)

    # Convert data to numpy array
    np_data = np.array(data, dtype=float)

    # Estimate degrees of freedom, mean and stdDev using MLE
    match(distribution):
        case 'normal':
            statistic, p_value = stats.shapiro(data)
        case 't':
            df_est, mean, stdDev = stats.t.fit(np_data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(
                np_data, 't', args=(df_est, mean, stdDev))
        case 'lognorm':
            shape, mean, stdDev = stats.lognorm.fit(np_data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(
                np_data, 'lognorm', args=(shape, mean, stdDev))
        case 'chi2':
            df_est, mean, stdDev = stats.chi2.fit(np_data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(
                np_data, 'chi2', args=(df_est, mean, stdDev))
        case 'gamma':
            shape, mean, stdDev = stats.lognorm.fit(np_data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(
                np_data, 'gamma', args=(shape, mean, stdDev))
        case 'beta':
            # Normalize data
            data_min, data_max = min(np_data), max(np_data)
            data_norm = (np_data - data_min) / (data_max - data_min)
            # Fit Beta distribution
            a, b, mean, stdDev = stats.beta.fit(data_norm, floc=0, fscale=1)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'beta', args=(a, b))
        case 'weibull':
            shape, mean, stdDev = stats.weibull_min.fit(np_data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(
                np_data, 'weibull_min', args=(shape, mean, stdDev))
        case 'exponential':
            stdDev = stats.expon.fit(np_data, floc=0)[1]
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(
                np_data, 'expon', args=(0, stdDev))
        case 'uniform':
            # Normalize data to range [0, 1]
            data_norm = (np_data - np.min(np_data)) / \
                (np.max(np_data) - np.min(np_data))
            statistic, p_value = stats.kstest(data_norm, 'uniform')
        case 'bernoulli':
            statistic = 0
            p_value = 0
            # Check if data is binary
            unique_values = np.unique(np_data)
            if np.array_equal(unique_values, [0, 1]):
                p_hat = np.mean(np_data)
                # Count observed frequencies
                count_0 = np.sum(np_data == 0)
                count_1 = np.sum(np_data == 1)
                observed = [count_0, count_1]
                # Expected frequencies based on estimated p
                n = len(np_data)
                expected = [(1 - p_hat) * n, p_hat * n]
                # Run chi-square test
                statistic, p_value = stats.chisquare(
                    f_obs=observed, f_exp=expected)
        case 'binomial':
            n = np_data.size
            p_hat = np.mean(np_data) / n
            # Get frequencies of each observed outcome
            observed_counts = np.bincount(np_data, minlength=n+1)
            observed_values = np.arange(len(observed_counts))
            # Calculate expected frequencies using binomial PMF
            expected_probs = stats.binom.pmf(observed_values, n, p_hat)
            expected_counts = expected_probs * len(np_data)
            # Filter out zero-expected to avoid division by zero in test
            nonzero = expected_counts > 0
            observed_counts = observed_counts[nonzero]
            expected_counts = expected_counts[nonzero]
            # Run chi-square test
            statistic, p_value = stats.chisquare(
                f_obs=observed_counts, f_exp=expected_counts)
        case 'geometric':
            p_hat = 1 / np.mean(np_data)
            # Get observed frequencies
            max_val = np.max(np_data)
            values = np.arange(1, max_val + 1)
            observed_counts = np.array([(np_data == k).sum() for k in values])
            # Expected probabilities using estimated p
            expected_probs = stats.geom.pmf(values, p_hat)
            expected_counts = expected_probs * len(np_data)
            # Filter out bins with expected < 5 (common chi-square rule)
            mask = expected_counts >= 5
            observed_counts = observed_counts[mask]
            expected_counts = expected_counts[mask]
            # Run chi-square test
            statistic, p_value = stats.chisquare(
                f_obs=observed_counts, f_exp=expected_counts)
        case 'poisson':
            lambda_hat = np.mean(np_data)
            # Observed frequencies
            values, counts = np.unique(np_data, return_counts=True)
            # Expected frequencies under Poisson(λ)
            expected_counts = stats.poisson.pmf(
                values, mu=lambda_hat) * len(np_data)
            # Chi-square test
            statistic = np.sum((counts - expected_counts)
                               ** 2 / expected_counts)
            dof = len(values) - 1 - 1  # subtract 1 for lambda estimation
            p_value = 1 - stats.chi2.cdf(statistic, df=dof)

    # Interpret the result
    # TODO p_value can be unassignedt a
    is_dist = p_value > 0.05  # Using 0.05 as the significance level

    result = {
        "dist_type": str(distribution),
        "is_dist": bool(is_dist),
        "p_value": float(p_value),  # Convert to float for JSON serialization
        "statistic": float(statistic)
    }
    return result

def get_scales(sequences):
    if not sequences:
        return {"error": "No data provided"}

    if isinstance(sequences, str):
        sequences = json.loads(sequences)

    currentStats = {}
    first = {feature: True for feature in FEATURE_SCALES}
    perSequenceResults = {feature: {} for feature in FEATURE_SCALES}

    for seq in sequences:
        for feature in FEATURE_SCALES:
            value = calculateValueForFeature(seq.upper(), FEATURE_SCALES[feature])
            if value is None:
                continue
            if first[feature]:
                currentStats[feature] = (value, value, 0, 0.0, 0.0)
                first[feature] = False
            else:
                currentStats[feature] = runningStats(value, currentStats[feature])
            perSequenceResults[feature][seq] = value

    results = {}
    for feature in FEATURE_SCALES:
        results[feature] = {
                "stats": {
                    "min": currentStats[feature][0],
                    "max": currentStats[feature][1],
                    "mean": currentStats[feature][3],
                    "stdDev": math.sqrt(currentStats[feature][4] / currentStats[feature][2])
                },
                "valuesPerSequence": perSequenceResults[feature]
            }

    return {"results": results}


def runningStats(newValue, currentStats):
    (min, max, count, mean, m2) = currentStats
    if newValue < min: min = newValue
    if newValue > max: max = newValue
    count += 1
    delta = newValue - mean
    mean += delta / count
    delta2 = newValue - mean
    m2 += delta * delta2
    return (min, max, count, mean, m2)


def calculateValueForFeature(sequence, dict):
    values = [dict[a] for a in sequence if a in dict]
    
    if not values:
        return None
    
    return sum(values) / len(values)


LETTERS = [
    'A', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
    'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S',
    'T', 'V', 'W', 'Y', 'X', 'U',
]
FEATURE_SCALES = {
  "hydrophobicity": {"A":0.14358913378319937, "R":-0.22636644169555728, "N":-0.2092242521622241, "D":-0.26473494857761126, "C":0.32931700684958476, "Q":-0.22784290932653717, "E":-0.2809654937064575, "G":-0.05574240859408246, "H":-0.0005694593018983487, "I":0.7394661181561407, "L":0.6727226738424296, "K":-0.21494542772443354, "M":0.4557449156253738, "F":0.76326618347678, "P":0.17041140131272003, "S":-0.1371795756074432, "T":-0.005209995452296512, "W":0.7069106029546537, "Y":0.42808513792254455, "V":0.5120052529094391}, 
  "freeEnergie": {"A":0.4126725685975706, "R":0.3976573097883449, "N":0.5376667922318099, "D":0.5498713549024209, "C":0.42070550702821014, "Q":0.4305812297852952, "E":0.3931500062963445, "G":0.6419613997574174, "H":0.44649404914002194, "I":0.32993634469537864, "L":0.37253441201227444, "K":0.4297431453605854, "M":0.35660015135749124, "F":0.378033855997586, "P":1.0, "S":0.4656483843114838, "T":0.4145832124838414, "W":0.3879077058059451, "Y":0.38068244136095986, "V":0.3340384406240167}, 
  "stability": {"A":0.3480633629471504, "R":0.34399187846000145, "N":0.2073746228973096, "D":0.12041433302943207, "C":0.5407968873115502, "Q":0.28641797103574157, "E":0.27396796651284466, "G":0.038922249361399465, "H":0.33801074196451336, "I":0.8616284467863063, "L":0.7118262537208974, "K":0.38132182563329614, "M":0.5233023271400615, "F":0.8570013100720518, "P":0.34592244625918867, "S":0.28260349645510846, "T":0.4461459771266177, "W":0.8491195216807631, "Y":0.7288116232206955, "V":0.7828956685436782}, 
  "volume": {"A":0.36602623291450886, "R":0.8238919538564463, "N":0.5371914111807752, "D":0.4837632806855753, "C":0.48213006245979795, "Q":0.6464190909849685, "E":0.617329380563794, "G":0.231896382746156, "H":0.6882483635889526, "I":0.6993281023998736, "L":0.6977921936967111, "K":0.7286885100866508, "M":0.7189429802894034, "F":0.8328210272765146, "P":0.47900880512587585, "S":0.391636744280506, "T":0.5098512092286421, "W":0.9792804979957268, "Y":0.8766364342249389, "V":0.5940467373991879}, 
  "alpha-helix": {"A":0.7442034901304289, "R":0.49965192974183026, "N":0.2922649694733262, "D":0.39245804612261465, "C":0.3041156248788227, "Q":0.5808341080712011, "E":0.7501169192456335, "G":0.07290246184485562, "H":0.4961365750670697, "I":0.4896085869580447, "L":0.7216557552587273, "K":0.5799675060484489, "M":0.794644214563068, "F":0.5549011221246851, "P":-0.03535290560938736, "S":0.25080549451114953, "T":0.2969457164912867, "W":0.5408691741732791, "Y":0.28905098834816, "V":0.4830710076268101}, 
  "beta-sheet": {"A":0.34956591911092894, "R":0.460550677798243, "N":0.22256084553921518, "D":0.18452618634543372, "C":0.5099790895042989, "Q":0.4453882634893641, "E":0.11317872915496889, "G":0.3274437242442998, "H":0.3872233691659867, "I":0.9199532659318971, "L":0.5989115344257007, "K":0.27558096039030416, "M":0.6135421560885467, "F":0.7066307354658885, "P":0.09494029912392414, "S":0.3628039141726376, "T":0.5799367947829297, "W":0.6295171062240904, "Y":0.7336981819919552, "V":0.8903504557212697}, 
  "coil": {"A":0.09663551689300753, "R":0.2678770347284752, "N":0.6591846813607345, "D":0.4775261018204119, "C":0.27029350887007075, "Q":0.1909684984175682, "E":0.15314799173070323, "G":0.6665124673407554, "H":0.36393670117956045, "I":-0.08149077849430328, "L":-0.05275135589796503, "K":0.3039878566804798, "M":-0.1346607990280012, "F":0.0003032555159309797, "P":0.9318164083836635, "S":0.5001012727728252, "T":0.3513196863356348, "W":0.07066763248303932, "Y":0.18765062236002322, "V":-0.13569056048760558}, 
  "mutability": {"A":0.8394984282043829, "R":0.7005642770375807, "N":0.935471554028255, "D":0.8076649092189944, "C":0.46720358906849135, "Q":0.7524464644790849, "E":0.7617643564712345, "G":0.580491892462965, "H":0.7086617314344656, "I":0.7934216484762722, "L":0.5042077479375525, "K":0.6777650210486031, "M":0.7530836433744573, "F":0.42598335312599045, "P":0.5863325894099859, "S":0.9617377032363953, "T":0.8622880399307542, "W":0.18472971296482607, "Y":0.4128250719264721, "V":0.7553781011236005}
}