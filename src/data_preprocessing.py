"""
Data preprocessing utilities for the movie recommendation system.

This module handles:
- Loading raw movie and rating data
- Feature extraction from movie titles and genres
- Train/test splitting based on timestamps
- Data cleaning and validation
"""

import pandas as pd
import numpy as np
import re
import warnings
from typing import Tuple, Dict, Any
from pathlib import Path

from config.settings import *

warnings.filterwarnings('ignore')


class MovieDataProcessor:
    """
    A comprehensive data processor for movie recommendation datasets.
    
    Handles everything from raw data loading to feature engineering
    for both collaborative and content-based filtering approaches.
    """
    
    def __init__(self):
        self.movies_df = None
        self.ratings_df = None
        self.combined_df = None
        self.train_df = None
        self.test_df = None
        
    def load_raw_data(self) -> None:
        """
        Load the raw movies and ratings CSV files.
        
        Expected format:
        - movies.csv: movieId, title, genres
        - ratings.csv: userId, movieId, rating, timestamp
        """
        print("📚 Loading raw data files...")
        
        try:
            # Load movie metadata
            self.movies_df = pd.read_csv(MOVIES_FILE)
            print(f"   ✅ Loaded {len(self.movies_df)} movies")
            
            # Load user ratings
            self.ratings_df = pd.read_csv(RATINGS_FILE)
            print(f"   ✅ Loaded {len(self.ratings_df)} ratings")
            
            # Basic data validation
            self._validate_data()
            
        except FileNotFoundError as e:
            raise FileNotFoundError(f"Data file not found: {e}")
        except Exception as e:
            raise RuntimeError(f"Error loading data: {e}")
    
    def _validate_data(self) -> None:
        """Perform basic validation on the loaded data."""
        # Check for required columns
        required_movie_cols = ['movieId', 'title', 'genres']
        required_rating_cols = ['userId', 'movieId', 'rating', 'timestamp']
        
        for col in required_movie_cols:
            if col not in self.movies_df.columns:
                raise ValueError(f"Missing required column in movies.csv: {col}")
                
        for col in required_rating_cols:
            if col not in self.ratings_df.columns:
                raise ValueError(f"Missing required column in ratings.csv: {col}")
        
        # Check for missing values
        print(f"   📊 Movies missing values: {self.movies_df.isnull().sum().sum()}")
        print(f"   📊 Ratings missing values: {self.ratings_df.isnull().sum().sum()}")
    
    def extract_movie_year(self, title: str) -> int:
        """
        Extract the year from a movie title.
        
        Most movie titles end with (YEAR), e.g., "Toy Story (1995)"
        If no year is found, defaults to 2000.
        
        Args:
            title: Movie title string
            
        Returns:
            Extracted year as integer
        """
        # Find all numbers in the title
        year_matches = re.findall(r'\d+', title)
        
        if year_matches:
            # Take the last number found (usually the year)
            potential_year = int(year_matches[-1])
            
            # Sanity check: must be a reasonable movie year
            if potential_year > 1900 and potential_year <= 2030:
                return potential_year
        
        # Default fallback year
        return 2000
    
    def create_genre_features(self, genres_series: pd.Series) -> pd.DataFrame:
        """
        Convert genre strings into one-hot encoded features.
        
        Example: "Action|Adventure|Sci-Fi" becomes separate binary columns
        for Action=1, Adventure=1, Sci-Fi=1, etc.
        
        Args:
            genres_series: Series containing pipe-separated genre strings
            
        Returns:
            DataFrame with binary genre columns
        """
        print("🎭 Creating genre features...")
        
        genre_df = pd.DataFrame()
        
        # Create a binary column for each possible genre
        for genre in ALL_GENRES:
            # Check if this genre appears in each movie's genre string
            genre_df[genre] = (
                genres_series
                .str.contains(genre, na=False)  # Handle NaN values
                .astype(int)
            )
        
        return genre_df
    
    def perform_train_test_split(self) -> None:
        """
        Split data into training and testing sets based on timestamps.
        
        Uses the most recent TEST_SIZE ratings as the test set,
        which simulates a realistic scenario where we predict future ratings.
        """
        print(f"📊 Splitting data (test size: {TEST_SIZE} ratings)...")
        
        # Sort by timestamp to ensure chronological splitting
        sorted_ratings = self.ratings_df.sort_values('timestamp')
        
        # Split based on number of ratings (not users)
        split_point = len(sorted_ratings) - TEST_SIZE
        
        self.train_df = sorted_ratings.iloc[:split_point].copy()
        self.test_df = sorted_ratings.iloc[split_point:].copy()
        
        print(f"   📈 Training set: {len(self.train_df)} ratings")
        print(f"   📉 Test set: {len(self.test_df)} ratings")
        print(f"   👥 Unique users in train: {self.train_df['userId'].nunique()}")
        print(f"   👥 Unique users in test: {self.test_df['userId'].nunique()}")
    
    def create_content_features(self) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        Create comprehensive feature sets for content-based filtering.
        
        Combines movie features (genres, year) with user features
        (viewing history, rating patterns).
        
        Returns:
            Tuple of (train_features, test_features) DataFrames
        """
        print("🔧 Engineering features for content-based filtering...")
        
        # Merge ratings with movie information
        train_content = pd.merge(self.train_df, self.movies_df, on='movieId', how='left')
        test_content = pd.merge(self.test_df, self.movies_df, on='movieId', how='left')
        
        # Extract year from movie titles
        print("   📅 Extracting movie years...")
        train_content['movieYear'] = train_content['title'].apply(self.extract_movie_year)
        test_content['movieYear'] = test_content['title'].apply(self.extract_movie_year)
        
        # Create genre features
        print("   🎭 Processing genres...")
        train_genres = self.create_genre_features(train_content['genres'])
        test_genres = self.create_genre_features(test_content['genres'])
        
        # Combine with main dataframes
        train_content = pd.concat([train_content, train_genres], axis=1)
        test_content = pd.concat([test_content, test_genres], axis=1)
        
        # Add user-level features
        print("   👤 Creating user features...")
        train_content, test_content = self._add_user_features(train_content, test_content)
        
        # Clean up unnecessary columns
        columns_to_drop = ['userId', 'movieId', 'timestamp', 'title', 'genres']
        
        # Prepare final feature sets
        X_train = train_content.drop(columns_to_drop + ['rating'], axis=1)
        y_train = train_content['rating']
        
        X_test = test_content.drop(columns_to_drop + ['rating'], axis=1)
        y_test = test_content['rating']
        
        # Store original identifiers for evaluation
        test_content_clean = test_content[['userId', 'movieId', 'rating']].copy()
        
        print(f"   ✅ Features created: {X_train.shape[1]} features")
        print(f"   ✅ Training samples: {len(X_train)}")
        print(f"   ✅ Test samples: {len(X_test)}")
        
        return (X_train, y_train, X_test, y_test, test_content_clean)
    
    def _add_user_features(self, train_df: pd.DataFrame, test_df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        Add user-level features like viewing history and rating patterns.
        
        This helps the model understand user behavior patterns.
        """
        # Calculate user statistics from training data only
        user_view_counts = train_df.groupby('userId').size()
        user_mean_ratings = train_df.groupby('userId')['rating'].mean()
        
        # Global fallbacks for new users (cold start problem)
        global_view_mean = int(user_view_counts.mean())
        global_rating_mean = user_mean_ratings.mean()
        
        print(f"      📊 Average user views: {global_view_mean}")
        print(f"      📊 Average user rating: {global_rating_mean:.2f}")
        
        # Add features to training set
        train_df['userViews'] = train_df['userId'].map(user_view_counts)
        
        # Add some realistic noise to user means (people's preferences can vary)
        noise = np.random.normal(0, USER_NOISE_STD, len(train_df))
        train_df['userMeans'] = train_df['userId'].map(user_mean_ratings) + noise
        
        # Add features to test set (with fallbacks for new users)
        test_df['userViews'] = (
            test_df['userId']
            .map(user_view_counts)
            .fillna(global_view_mean)
        )
        
        test_df['userMeans'] = (
            test_df['userId']
            .map(user_mean_ratings)
            .fillna(global_rating_mean)
        )
        
        return train_df, test_df
    
    def get_collaborative_data(self) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """
        Prepare data specifically for collaborative filtering.
        
        Returns clean train/test splits with just the essential columns.
        """
        if self.train_df is None or self.test_df is None:
            raise ValueError("Must perform train/test split first")
        
        return self.train_df.copy(), self.test_df.copy()
    
    def process_all_data(self) -> Dict[str, Any]:
        """
        Complete data processing pipeline.
        
        Loads raw data, performs all feature engineering, and returns
        everything needed for training and evaluation.
        
        Returns:
            Dictionary containing all processed datasets and metadata
        """
        print("🚀 Starting complete data processing pipeline...")
        print("=" * 60)
        
        # Step 1: Load raw data
        self.load_raw_data()
        
        # Step 2: Perform train/test split
        self.perform_train_test_split()
        
        # Step 3: Prepare collaborative filtering data
        train_collab, test_collab = self.get_collaborative_data()
        
        # Step 4: Create content-based features
        content_data = self.create_content_features()
        X_train, y_train, X_test, y_test, test_identifiers = content_data
        
        print("=" * 60)
        print("✅ Data processing complete!")
        
        return {
            'collaborative': {
                'train': train_collab,
                'test': test_collab
            },
            'content_based': {
                'X_train': X_train,
                'y_train': y_train,
                'X_test': X_test,
                'y_test': y_test,
                'test_identifiers': test_identifiers
            },
            'metadata': {
                'n_users': self.ratings_df['userId'].nunique(),
                'n_movies': self.ratings_df['movieId'].nunique(),
                'n_ratings': len(self.ratings_df),
                'rating_range': (self.ratings_df['rating'].min(), self.ratings_df['rating'].max())
            }
        }


def main():
    """Example usage of the data processor."""
    processor = MovieDataProcessor()
    processed_data = processor.process_all_data()
    
    # Print some summary statistics
    metadata = processed_data['metadata']
    print(f"\n📊 Dataset Summary:")
    print(f"   Users: {metadata['n_users']:,}")
    print(f"   Movies: {metadata['n_movies']:,}")
    print(f"   Ratings: {metadata['n_ratings']:,}")
    print(f"   Rating Range: {metadata['rating_range'][0]} - {metadata['rating_range'][1]}")


if __name__ == "__main__":
    main()