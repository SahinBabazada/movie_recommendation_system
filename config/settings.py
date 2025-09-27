"""
Configuration settings for the movie recommendation system.
This file centralizes all the important parameters and paths.
"""

import os
from pathlib import Path

# ============================================================================
# PROJECT PATHS
# ============================================================================
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
PROCESSED_DATA_DIR = DATA_DIR / "processed"
MODELS_DIR = BASE_DIR / "models" / "saved_models"
NOTEBOOKS_DIR = BASE_DIR / "notebooks"

# Create directories if they don't exist
for dir_path in [DATA_DIR, RAW_DATA_DIR, PROCESSED_DATA_DIR, MODELS_DIR, NOTEBOOKS_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# ============================================================================
# DATA FILES
# ============================================================================
MOVIES_FILE = RAW_DATA_DIR / "movies.csv"
RATINGS_FILE = RAW_DATA_DIR / "ratings.csv"

# ============================================================================
# MODEL PARAMETERS
# ============================================================================
# Train/test split configuration
TEST_SIZE = 20000  # Number of most recent ratings to use for testing

# Collaborative filtering parameters
MIN_CORRELATION = 0.0  # Minimum correlation threshold for user similarity
MIN_NEIGHBORS = 1      # Minimum number of neighbors required for prediction

# Content-based filtering parameters
CATBOOST_PARAMS = {
    'iterations': 1000,
    'learning_rate': 0.1,
    'depth': 6,
    'random_seed': 42,
    'verbose': False
}

# User feature engineering
USER_NOISE_STD = 0.1  # Standard deviation for noise added to user mean ratings

# ============================================================================
# GENRE CATEGORIES
# ============================================================================
# All possible movie genres in the dataset
ALL_GENRES = [
    'Adventure', 'Comedy', 'Action', 'Mystery', 'Crime', 'Thriller',
    'Drama', 'Animation', 'Children', 'Horror', 'Documentary',
    'Sci-Fi', 'Fantasy', 'Film-Noir', 'Western', 'Musical', 'Romance',
    '(no genres listed)', 'War'
]

# ============================================================================
# EVALUATION SETTINGS
# ============================================================================
# DSG@K evaluation parameters
DSG_K = 2  # Number of top recommendations to consider for DSG calculation

# ============================================================================
# VISUALIZATION SETTINGS
# ============================================================================
# Matplotlib styling for beautiful plots
PLOT_STYLE = {
    'lines.linewidth': 5,
    'xtick.major.size': 20,
    'xtick.major.width': 5,
    'xtick.labelsize': 20,
    'xtick.color': '#FF5533',
    'ytick.major.size': 20,
    'ytick.major.width': 5,
    'ytick.labelsize': 20,
    'ytick.color': '#FF5533',
    'axes.labelsize': 20,
    'axes.titlesize': 20,
    'axes.titlecolor': '#00B050',
    'axes.labelcolor': '#00B050'
}