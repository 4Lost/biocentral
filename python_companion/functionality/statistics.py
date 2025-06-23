import json
import numpy as np

from scipy import stats

def test_distributions(json_data, types):
    distributions = types.split("|")
    print(distributions)
    results = []
    for type in distributions:
        print(type)
        results.append(dist_tester(json_data, type))
    return results

def dist_tester(json_data, type):
    data = json_data

    if not data:
        print("Error: No data provided", flush=True)
        return {"error": "No data provided"}

    if isinstance(data, str):
        data = json.loads(data)
    
    # Convert data to numpy array
    np_data = np.array(data, dtype=float)

    # Estimate degrees of freedom, mean and stdDev using MLE
    match(type):
        case 'normal':
            # Perform D’Agostino and Pearson’s Test
            statistic, p_value = stats.normaltest(np_data)
        case 't':
            print('2')
            df_est, mean, stdDev = stats.t.fit(data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 't', args=(df_est, mean, stdDev))
        case 'lognorm':
            shape, mean, stdDev = stats.lognorm.fit(data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'lognorm', args=(shape, mean, stdDev))
        case 'chi2':
            df_est, mean, stdDev = stats.chi2.fit(data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'chi2', args=(df_est, mean, stdDev))
        case 'gamma':
            shape, mean, stdDev = stats.lognorm.fit(data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'gamma', args=(shape, mean, stdDev))
        case 'beta':
            # Normalize data
            data_min, data_max = min(data), max(data)
            data_norm = (data - data_min) / (data_max - data_min)
            # Fit Beta distribution
            a, b, mean, stdDev = stats.beta.fit(data_norm, floc=0, fscale=1)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'beta', args=(a, b))
        case 'weibull':
            shape, mean, stdDev = stats.weibull_min.fit(data)
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'weibull_min', args=(shape, mean, stdDev))
        case 'exponential':
            stdDev = stats.expon.fit(data, floc=0)[1]
            # Perform Kolmogorow-Smirnow test
            statistic, p_value = stats.kstest(np_data, 'expon', args=(0, stdDev))
        case 'uniform':
            # Normalize data to range [0, 1]
            data_norm = (data - np.min(data)) / (np.max(data) - np.min(data))
            statistic, p_value = stats.kstest(data_norm, 'uniform')
        case 'bernoulli':
            statistic = 0
            p_value = 0
            # Check if data is binary
            unique_values = np.unique(data)
            if np.array_equal(unique_values, [0, 1]):
                p_hat = np.mean(data)
                # Count observed frequencies
                count_0 = np.sum(data == 0)
                count_1 = np.sum(data == 1)
                observed = [count_0, count_1]
                # Expected frequencies based on estimated p
                n = len(data)
                expected = [(1 - p_hat) * n, p_hat * n]
                # Run chi-square test
                statistic, p_value = stats.chisquare(f_obs=observed, f_exp=expected)
        case 'binomial':
            n = data.size
            p_hat = np.mean(data) / n
            # Get frequencies of each observed outcome
            observed_counts = np.bincount(data, minlength=n+1)
            observed_values = np.arange(len(observed_counts))
            # Calculate expected frequencies using binomial PMF
            expected_probs = stats.binom.pmf(observed_values, n, p_hat)
            expected_counts = expected_probs * len(data)
            # Filter out zero-expected to avoid division by zero in test
            nonzero = expected_counts > 0
            observed_counts = observed_counts[nonzero]
            expected_counts = expected_counts[nonzero]
            # Run chi-square test
            statistic, p_value = stats.chisquare(f_obs=observed_counts, f_exp=expected_counts)
        case 'geometric':
            p_hat = 1 / np.mean(data)
            # Get observed frequencies
            max_val = np.max(data)
            values = np.arange(1, max_val + 1)
            observed_counts = np.array([(data == k).sum() for k in values])
            # Expected probabilities using estimated p
            expected_probs = stats.geom.pmf(values, p_hat)
            expected_counts = expected_probs * len(data)
            # Filter out bins with expected < 5 (common chi-square rule)
            mask = expected_counts >= 5
            observed_counts = observed_counts[mask]
            expected_counts = expected_counts[mask]
            # Run chi-square test
            statistic, p_value = stats.chisquare(f_obs=observed_counts, f_exp=expected_counts)
        case 'poisson':
            lambda_hat = np.mean(data)
            # Observed frequencies
            values, counts = np.unique(data, return_counts=True)
            # Expected frequencies under Poisson(λ)
            expected_counts = stats.poisson.pmf(values, mu=lambda_hat) * len(data)
            # Chi-square test
            statistic = np.sum((counts - expected_counts) ** 2 / expected_counts)
            dof = len(values) - 1 - 1  # subtract 1 for lambda estimation
            p_value = 1 - stats.chi2.cdf(statistic, df=dof)      

    # Interpret the result
    is_dist = p_value > 0.05  # Using 0.05 as the significance level

    result = {
        "dist_type": str(type),
        "is_dist": bool(is_dist),
        "p_value": float(p_value),  # Convert to float for JSON serialization
        "statistic": float(statistic)
    }
    # print(f"Result: {result}", flush=True)
    return result