"""
Content-Based Filtering using CatBoost.

This module implements a machine learning approach to recommendations
that learns patterns from movie features (genres, year) and user behavior
patterns (viewing history, rating tendencies).

Unlike collaborative filtering which says "users like you enjoyed this",
content-based filtering says "based on what you've liked before, you'll
probably enjoy this because it has similar characteristics."
"""

import pandas as pd
import numpy as np
import pickle
import warnings
from typing import Dict, List, Tuple, Optional
from pathlib import Path

from catboost import CatBoostRegressor, Pool
from sklearn.metrics import mean_squared_error, mean_absolute_error

from config.settings import CATBOOST_PARAMS, MODELS_DIR

warnings.filterwarnings('ignore')


class ContentBasedRecommender:
    """
    A content-based recommender system using gradient boosting.
    
    This system learns to predict ratings based on:
    - Movie characteristics (genre, year)
    - User patterns (how many movies they watch, their average ratings)
    - Implicit preferences (learned from training data)
    
    It's particularly good at handling the "cold start" problem where
    we have new users or movies with limited interaction data.
    """
    
    def __init__(self, model_params: Dict = None):
        """
        Initialize the content-based recommender.
        
        Args:
            model_params: CatBoost parameters (uses defaults if None)
        """
        self.model_params = model_params or CATBOOST_PARAMS.copy()
        self.model = None
        self.feature_names = None
        self.categorical_features = ['movieYear']  # Features that should be treated as categories
        self.is_fitted = False
        
    def fit(self, X_train: pd.DataFrame, y_train: pd.Series, 
            X_val: pd.DataFrame = None, y_val: pd.Series = None) -> None:
        """
        Train the content-based model on movie and user features.
        
        Args:
            X_train: Training features (movie + user characteristics)
            y_train: Training targets (ratings)
            X_val: Optional validation features for early stopping
            y_val: Optional validation targets
        """
        print("🤖 Training content-based recommender...")
        
        self.feature_names = list(X_train.columns)
        print(f"   📊 Features: {len(self.feature_names)}")
        print(f"   🎯 Training samples: {len(X_train)}")
        
        # Initialize the CatBoost model
        self.model = CatBoostRegressor(**self.model_params)
        
        # Prepare training data
        train_pool = Pool(
            data=X_train,
            label=y_train,
            cat_features=self.categorical_features
        )
        
        # Prepare validation data if provided
        eval_set = None
        if X_val is not None and y_val is not None:
            val_pool = Pool(
                data=X_val,
                label=y_val,
                cat_features=self.categorical_features
            )
            eval_set = val_pool
            print(f"   📈 Validation samples: {len(X_val)}")
        
        # Train the model
        print("   🚀 Starting training...")
        self.model.fit(
            train_pool,
            eval_set=eval_set,
            verbose=100,  # Print progress every 100 iterations
            plot=False    # Disable plotting in console
        )
        
        self.is_fitted = True
        
        # Display feature importance
        self._show_feature_importance()
        
        print("   ✅ Training completed!")
    
    def _show_feature_importance(self, top_n: int = 10) -> None:
        """Display the most important features learned by the model."""
        if not self.is_fitted:
            return
        
        feature_importance = self.model.get_feature_importance()
        importance_df = pd.DataFrame({
            'feature': self.feature_names,
            'importance': feature_importance
        }).sort_values('importance', ascending=False)
        
        print(f"\n   🔍 Top {top_n} Most Important Features:")
        for i, (_, row) in enumerate(importance_df.head(top_n).iterrows()):
            print(f"      {i+1:2d}. {row['feature']:<20} {row['importance']:>8.1f}")
    
    def predict(self, X: pd.DataFrame) -> np.ndarray:
        """
        Predict ratings for given features.
        
        Args:
            X: Features to predict on
            
        Returns:
            Array of predicted ratings
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before making predictions")
        
        # Ensure we have the same features as training
        if list(X.columns) != self.feature_names:
            missing_features = set(self.feature_names) - set(X.columns)
            extra_features = set(X.columns) - set(self.feature_names)
            
            if missing_features:
                raise ValueError(f"Missing features: {missing_features}")
            if extra_features:
                print(f"   ⚠️  Extra features will be ignored: {extra_features}")
                X = X[self.feature_names]
        
        predictions = self.model.predict(X)
        
        # Ensure predictions are within valid rating range
        predictions = np.clip(predictions, 0.5, 5.0)
        
        return predictions
    
    def evaluate(self, X_test: pd.DataFrame, y_test: pd.Series) -> Dict[str, float]:
        """
        Evaluate model performance on test data.
        
        Args:
            X_test: Test features
            y_test: True test ratings
            
        Returns:
            Dictionary of evaluation metrics
        """
        print("📊 Evaluating content-based model...")
        
        predictions = self.predict(X_test)
        
        metrics = {
            'rmse': np.sqrt(mean_squared_error(y_test, predictions)),
            'mae': mean_absolute_error(y_test, predictions),
            'r2': self.model.score(X_test, y_test)
        }
        
        print(f"   📈 RMSE: {metrics['rmse']:.4f}")
        print(f"   📈 MAE:  {metrics['mae']:.4f}")
        print(f"   📈 R²:   {metrics['r2']:.4f}")
        
        return metrics
    
    def get_movie_recommendations(self, user_features: Dict, 
                                 movie_catalog: pd.DataFrame,
                                 n_recommendations: int = 10) -> List[Dict]:
        """
        Generate movie recommendations for a user.
        
        Args:
            user_features: Dictionary with user characteristics
                          (e.g., {'userViews': 50, 'userMeans': 4.2})
            movie_catalog: DataFrame with movie features
            n_recommendations: Number of recommendations to return
            
        Returns:
            List of recommended movies with predicted ratings
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before making recommendations")
        
        print(f"🎬 Generating {n_recommendations} recommendations...")
        
        # Create feature matrix by combining user features with each movie
        recommendation_features = []
        
        for _, movie in movie_catalog.iterrows():
            # Combine movie features with user features
            combined_features = {**movie.to_dict(), **user_features}
            recommendation_features.append(combined_features)
        
        # Convert to DataFrame
        features_df = pd.DataFrame(recommendation_features)
        
        # Ensure we have all required features
        missing_features = set(self.feature_names) - set(features_df.columns)
        if missing_features:
            print(f"   ⚠️  Missing features, filling with defaults: {missing_features}")
            for feature in missing_features:
                features_df[feature] = 0  # Default value
        
        # Reorder columns to match training
        features_df = features_df[self.feature_names]
        
        # Predict ratings
        predicted_ratings = self.predict(features_df)
        
        # Create recommendations list
        recommendations = []
        for i, (_, movie) in enumerate(movie_catalog.iterrows()):
            recommendations.append({
                'movieId': movie.get('movieId', i),
                'predicted_rating': predicted_ratings[i],
                'movie_features': movie.to_dict()
            })
        
        # Sort by predicted rating and return top N
        recommendations.sort(key=lambda x: x['predicted_rating'], reverse=True)
        
        return recommendations[:n_recommendations]
    
    def explain_prediction(self, X_sample: pd.DataFrame, 
                          sample_idx: int = 0) -> Dict:
        """
        Explain a prediction using SHAP-like feature contributions.
        
        Args:
            X_sample: Features for explanation
            sample_idx: Index of sample to explain
            
        Returns:
            Dictionary with feature contributions
        """
        if not self.is_fitted:
            raise ValueError("Model must be fitted before explaining predictions")
        
        # Get prediction
        prediction = self.predict(X_sample.iloc[[sample_idx]])[0]
        
        # Get feature values for this sample
        sample_features = X_sample.iloc[sample_idx]
        
        # For a full explanation, we'd need SHAP or similar
        # Here we provide a simplified explanation based on feature importance
        feature_importance = self.model.get_feature_importance()
        
        explanation = {
            'predicted_rating': prediction,
            'feature_contributions': []
        }
        
        for feature, importance in zip(self.feature_names, feature_importance):
            feature_value = sample_features[feature]
            
            explanation['feature_contributions'].append({
                'feature': feature,
                'value': feature_value,
                'importance': importance,
                'contribution_strength': 'high' if importance > np.percentile(feature_importance, 75) else 'medium' if importance > np.percentile(feature_importance, 25) else 'low'
            })
        
        # Sort by importance
        explanation['feature_contributions'].sort(
            key=lambda x: x['importance'], reverse=True
        )
        
        return explanation
    
    def save_model(self, filepath: str = None) -> str:
        """
        Save the trained model to disk.
        
        Args:
            filepath: Where to save the model (auto-generated if None)
            
        Returns:
            Path where model was saved
        """
        if not self.is_fitted:
            raise ValueError("Cannot save unfitted model")
        
        if filepath is None:
            filepath = MODELS_DIR / "content_based_model.cbm"
        
        # Ensure directory exists
        Path(filepath).parent.mkdir(parents=True, exist_ok=True)
        
        # Save the model
        self.model.save_model(str(filepath))
        
        # Also save metadata
        metadata = {
            'feature_names': self.feature_names,
            'categorical_features': self.categorical_features,
            'model_params': self.model_params
        }
        
        metadata_path = str(filepath).replace('.cbm', '_metadata.pkl')
        with open(metadata_path, 'wb') as f:
            pickle.dump(metadata, f)
        
        print(f"   💾 Model saved to: {filepath}")
        return str(filepath)
    
    def load_model(self, filepath: str) -> None:
        """
        Load a previously saved model.
        
        Args:
            filepath: Path to the saved model
        """
        # Load the model
        self.model = CatBoostRegressor()
        self.model.load_model(filepath)
        
        # Load metadata
        metadata_path = filepath.replace('.cbm', '_metadata.pkl')
        try:
            with open(metadata_path, 'rb') as f:
                metadata = pickle.load(f)
            
            self.feature_names = metadata['feature_names']
            self.categorical_features = metadata['categorical_features']
            self.model_params = metadata['model_params']
            
        except FileNotFoundError:
            print("   ⚠️  Metadata file not found, using defaults")
            self.feature_names = None
            self.categorical_features = ['movieYear']
        
        self.is_fitted = True
        print(f"   📂 Model loaded from: {filepath}")


def create_user_profile(user_ratings: pd.DataFrame, 
                       movie_features: pd.DataFrame) -> Dict:
    """
    Create a user profile based on their rating history.
    
    Analyzes what genres/years they prefer and their rating patterns.
    
    Args:
        user_ratings: User's historical ratings
        movie_features: Movie characteristics
        
    Returns:
        Dictionary with user profile features
    """
    # Merge ratings with movie features
    user_movies = pd.merge(user_ratings, movie_features, on='movieId', how='left')
    
    # Calculate user preferences
    profile = {
        'userViews': len(user_ratings),
        'userMeans': user_ratings['rating'].mean(),
        'preferred_rating_range': user_ratings['rating'].std(),
    }
    
    # Genre preferences (weighted by rating)
    genre_columns = [col for col in user_movies.columns if col in [
        'Adventure', 'Comedy', 'Action', 'Mystery', 'Crime', 'Thriller',
        'Drama', 'Animation', 'Children', 'Horror', 'Documentary',
        'Sci-Fi', 'Fantasy', 'Film-Noir', 'Western', 'Musical', 'Romance', 'War'
    ]]
    
    for genre in genre_columns:
        if genre in user_movies.columns:
            # Weight by rating (higher rated movies contribute more)
            genre_ratings = user_movies[user_movies[genre] == 1]['rating']
            if len(genre_ratings) > 0:
                profile[f'{genre}_preference'] = genre_ratings.mean()
            else:
                profile[f'{genre}_preference'] = 0
    
    return profile


def main():
    """Example usage of the content-based recommender."""
    from data_preprocessing import MovieDataProcessor
    
    # Load and preprocess data
    processor = MovieDataProcessor()
    processed_data = processor.process_all_data()
    
    content_data = processed_data['content_based']
    X_train = content_data['X_train']
    y_train = content_data['y_train']
    X_test = content_data['X_test']
    y_test = content_data['y_test']
    
    # Train the model
    recommender = ContentBasedRecommender()
    recommender.fit(X_train, y_train)
    
    # Evaluate performance
    metrics = recommender.evaluate(X_test, y_test)
    
    # Save the model
    model_path = recommender.save_model()
    
    # Generate sample recommendation
    sample_user = {
        'userViews': 25,
        'userMeans': 4.1,
        'Action': 1, 'Comedy': 0, 'Drama': 1,  # User likes action and drama
        'movieYear': 2020  # Prefers recent movies
    }
    
    print(f"\n🎯 Sample User Profile: {sample_user}")
    print("   (In a real system, this would be derived from the user's rating history)")


if __name__ == "__main__":
    main()