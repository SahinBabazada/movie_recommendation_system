"""
User-based Collaborative Filtering implementation.

This module implements the classic "people who liked what you liked also liked this" 
approach to recommendations. It finds similar users based on rating patterns
and uses their preferences to predict what the target user might enjoy.

The magic happens through correlation - if two users rate movies similarly,
they're considered neighbors, and their opinions influence each other's recommendations.
"""

import pandas as pd
import numpy as np
import warnings
from typing import List, Dict, Tuple, Optional
from tqdm import tqdm

from config.settings import MIN_CORRELATION, MIN_NEIGHBORS

warnings.filterwarnings('ignore')


class UserBasedCollaborativeFilter:
    """
    A user-based collaborative filtering recommender system.
    
    This class finds similar users and uses their ratings to predict
    what other users might like. It's like asking "What did people 
    with similar taste to mine enjoy?"
    
    The algorithm:
    1. Calculate correlations between all users
    2. For each user, find similar users (neighbors)
    3. Use neighbor ratings to predict unknown ratings
    4. Weight predictions by how similar each neighbor is
    """
    
    def __init__(self, min_correlation: float = MIN_CORRELATION, 
                 min_neighbors: int = MIN_NEIGHBORS):
        """
        Initialize the collaborative filter.
        
        Args:
            min_correlation: Minimum correlation threshold for considering users as neighbors
            min_neighbors: Minimum number of neighbors required to make a prediction
        """
        self.min_correlation = min_correlation
        self.min_neighbors = min_neighbors
        self.user_correlations = None
        self.user_means = None
        self.training_data = None
        
    def fit(self, train_data: pd.DataFrame) -> None:
        """
        Train the collaborative filter on historical rating data.
        
        This step computes user-user correlations and stores training data
        for later use in prediction.
        
        Args:
            train_data: DataFrame with columns [userId, movieId, rating, timestamp]
        """
        print("🤝 Training collaborative filtering model...")
        
        self.training_data = train_data.copy()
        
        # Create user-movie rating matrix
        print("   📊 Creating user-movie matrix...")
        pivot_table = train_data.pivot_table(
            index='movieId', 
            columns='userId', 
            values='rating'
        )
        
        # Compute correlations between all pairs of users
        print("   🔗 Computing user correlations...")
        user_correlations = pivot_table.corr()
        
        # Convert correlation matrix to long format for easier processing
        # This creates a DataFrame with columns: userId1, userId2, correlation
        correlations_long = (
            user_correlations
            .stack()
            .rename_axis(['userId1', 'userId2'])
            .reset_index()
        )
        correlations_long.columns = ['userId1', 'userId2', 'corr']
        
        # Keep only positive correlations (negative correlations mean opposite preferences)
        self.user_correlations = correlations_long[
            correlations_long['corr'] >= self.min_correlation
        ]
        
        # Compute each user's average rating for normalization
        self.user_means = train_data.groupby('userId')['rating'].mean()
        
        print(f"   ✅ Found {len(self.user_correlations)} user pairs with positive correlation")
        print(f"   ✅ Average correlation: {self.user_correlations['corr'].mean():.3f}")
    
    def predict_for_user(self, user_id: int, movies_to_predict: List[int]) -> pd.DataFrame:
        """
        Predict ratings for a specific user on a list of movies.
        
        The prediction formula:
        prediction(user, movie) = user_mean + 
            sum(neighbor_rating - neighbor_mean) * correlation / sum(correlations)
        
        Args:
            user_id: The target user ID
            movies_to_predict: List of movie IDs to predict ratings for
            
        Returns:
            DataFrame with columns [movieId, prediction, userId]
        """
        # Check if user exists in training data
        if user_id not in self.training_data['userId'].unique():
            print(f"   ⚠️  User {user_id} not found in training data (cold start)")
            return pd.DataFrame()
        
        # Find users similar to the target user
        similar_users = self.user_correlations[
            self.user_correlations['userId1'] == user_id
        ]
        
        if len(similar_users) < self.min_neighbors:
            print(f"   ⚠️  User {user_id} has insufficient neighbors ({len(similar_users)})")
            return pd.DataFrame()
        
        # Get the neighbor user IDs
        neighbor_ids = similar_users['userId2'].values
        
        # Filter training data to only include ratings from neighbors
        neighbor_ratings = self.training_data[
            self.training_data['userId'].isin(neighbor_ids) &
            self.training_data['movieId'].isin(movies_to_predict)
        ]
        
        if neighbor_ratings.empty:
            print(f"   ⚠️  No neighbor ratings found for user {user_id}")
            return pd.DataFrame()
        
        # Merge with correlation data
        neighbor_ratings = pd.merge(
            neighbor_ratings,
            similar_users[['userId2', 'corr']],
            left_on='userId',
            right_on='userId2',
            how='left'
        )
        
        # Add each neighbor's average rating
        neighbor_ratings['neighbor_mean'] = (
            neighbor_ratings['userId'].map(self.user_means)
        )
        
        # Calculate rating deviations from each neighbor's average
        neighbor_ratings['rating_deviation'] = (
            neighbor_ratings['rating'] - neighbor_ratings['neighbor_mean']
        )
        
        # Weight deviations by correlation strength
        neighbor_ratings['weighted_deviation'] = (
            neighbor_ratings['rating_deviation'] * neighbor_ratings['corr']
        )
        
        # For each movie, compute the prediction
        movie_predictions = []
        target_user_mean = self.user_means.get(user_id, 3.0)  # Default to neutral rating
        
        for movie_id in movies_to_predict:
            movie_data = neighbor_ratings[neighbor_ratings['movieId'] == movie_id]
            
            if movie_data.empty:
                continue
            
            # Sum of weighted deviations
            numerator = movie_data['weighted_deviation'].sum()
            # Sum of correlations (normalization factor)
            denominator = movie_data['corr'].sum()
            
            if denominator > 0:
                prediction = target_user_mean + (numerator / denominator)
                # Clamp prediction to valid rating range
                prediction = max(0.5, min(5.0, prediction))
                
                movie_predictions.append({
                    'movieId': movie_id,
                    'prediction': prediction,
                    'userId': user_id,
                    'n_neighbors': len(movie_data)
                })
        
        return pd.DataFrame(movie_predictions)
    
    def predict(self, test_data: pd.DataFrame) -> pd.DataFrame:
        """
        Generate predictions for all user-movie pairs in the test set.
        
        Args:
            test_data: DataFrame with columns [userId, movieId, rating, timestamp]
            
        Returns:
            DataFrame with predictions and actual ratings for evaluation
        """
        print("🔮 Generating collaborative filtering predictions...")
        
        all_predictions = []
        unique_users = test_data['userId'].unique()
        
        print(f"   👥 Processing {len(unique_users)} users...")
        
        # Process each user individually
        for user_id in tqdm(unique_users, desc="Predicting ratings"):
            # Get movies this user rated in the test set
            user_test_data = test_data[test_data['userId'] == user_id]
            movies_to_predict = user_test_data['movieId'].tolist()
            
            # Generate predictions for this user
            user_predictions = self.predict_for_user(user_id, movies_to_predict)
            
            if not user_predictions.empty:
                all_predictions.append(user_predictions)
        
        if not all_predictions:
            print("   ⚠️  No predictions could be generated!")
            return pd.DataFrame()
        
        # Combine all predictions
        predictions_df = pd.concat(all_predictions, ignore_index=True)
        
        # Merge with actual ratings for evaluation
        final_predictions = pd.merge(
            predictions_df,
            test_data[['userId', 'movieId', 'rating']],
            on=['userId', 'movieId'],
            how='inner'
        )
        
        print(f"   ✅ Generated {len(final_predictions)} predictions")
        print(f"   📊 Coverage: {len(final_predictions) / len(test_data) * 100:.1f}% of test set")
        
        return final_predictions
    
    def get_top_recommendations(self, user_id: int, n_recommendations: int = 10,
                              exclude_seen: bool = True) -> List[Dict]:
        """
        Get top movie recommendations for a specific user.
        
        Args:
            user_id: Target user ID
            n_recommendations: Number of recommendations to return
            exclude_seen: Whether to exclude movies the user has already rated
            
        Returns:
            List of dictionaries with movieId and predicted rating
        """
        if self.training_data is None:
            raise ValueError("Model must be fitted first")
        
        # Get all movies in the system
        all_movies = self.training_data['movieId'].unique()
        
        if exclude_seen:
            # Remove movies the user has already rated
            user_movies = self.training_data[
                self.training_data['userId'] == user_id
            ]['movieId'].unique()
            
            candidate_movies = [m for m in all_movies if m not in user_movies]
        else:
            candidate_movies = all_movies
        
        # Get predictions for all candidate movies
        predictions = self.predict_for_user(user_id, candidate_movies)
        
        if predictions.empty:
            return []
        
        # Sort by predicted rating and return top N
        top_recommendations = (
            predictions
            .nlargest(n_recommendations, 'prediction')
            .to_dict('records')
        )
        
        return top_recommendations
    
    def explain_recommendation(self, user_id: int, movie_id: int) -> Dict:
        """
        Provide an explanation for why a particular movie was recommended.
        
        Args:
            user_id: Target user ID
            movie_id: Movie ID to explain
            
        Returns:
            Dictionary with explanation details
        """
        # Find similar users who rated this movie
        similar_users = self.user_correlations[
            self.user_correlations['userId1'] == user_id
        ]
        
        neighbor_ratings = pd.merge(
            similar_users,
            self.training_data[self.training_data['movieId'] == movie_id],
            left_on='userId2',
            right_on='userId',
            how='inner'
        )
        
        if neighbor_ratings.empty:
            return {"explanation": "No similar users found who rated this movie"}
        
        # Sort by correlation strength
        top_neighbors = neighbor_ratings.nlargest(5, 'corr')
        
        explanation = {
            "movie_id": movie_id,
            "n_similar_users": len(neighbor_ratings),
            "avg_neighbor_rating": neighbor_ratings['rating'].mean(),
            "top_neighbors": [
                {
                    "user_id": row['userId2'],
                    "correlation": row['corr'],
                    "rating": row['rating']
                }
                for _, row in top_neighbors.iterrows()
            ]
        }
        
        return explanation


def calculate_user_similarity_matrix(ratings_df: pd.DataFrame) -> pd.DataFrame:
    """
    Utility function to calculate and visualize user similarity patterns.
    
    Args:
        ratings_df: DataFrame with user ratings
        
    Returns:
        User-user correlation matrix
    """
    print("📊 Calculating user similarity matrix...")
    
    # Create user-movie matrix
    user_movie_matrix = ratings_df.pivot_table(
        index='userId', 
        columns='movieId', 
        values='rating'
    )
    
    # Calculate correlations
    similarity_matrix = user_movie_matrix.corr()
    
    print(f"   ✅ Computed similarities for {len(similarity_matrix)} users")
    print(f"   📈 Average similarity: {similarity_matrix.values[np.triu_indices_from(similarity_matrix.values, k=1)].mean():.3f}")
    
    return similarity_matrix


def main():
    """Example usage of the collaborative filtering system."""
    from data_preprocessing import MovieDataProcessor
    
    # Load and preprocess data
    processor = MovieDataProcessor()
    processed_data = processor.process_all_data()
    
    train_data = processed_data['collaborative']['train']
    test_data = processed_data['collaborative']['test']
    
    # Train collaborative filter
    cf_model = UserBasedCollaborativeFilter(min_correlation=0.1, min_neighbors=2)
    cf_model.fit(train_data)
    
    # Generate predictions
    predictions = cf_model.predict(test_data)
    
    if not predictions.empty:
        # Show some results
        print(f"\n🎯 Prediction Results:")
        print(f"   Generated {len(predictions)} predictions")
        print(f"   Average predicted rating: {predictions['prediction'].mean():.2f}")
        print(f"   Average actual rating: {predictions['rating'].mean():.2f}")
        
        # Show sample predictions
        print(f"\n📋 Sample Predictions:")
        sample = predictions.head(10)
        for _, row in sample.iterrows():
            print(f"   User {row['userId']}, Movie {row['movieId']}: "
                  f"Predicted {row['prediction']:.2f}, Actual {row['rating']:.1f}")


if __name__ == "__main__":
    main()