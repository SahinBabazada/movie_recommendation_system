"""
Movie Recommendation System - Main Entry Point

This is the main script that orchestrates the entire recommendation system pipeline:
1. Data loading and preprocessing
2. Training collaborative filtering, content-based, and hybrid models
3. Evaluation and comparison of different approaches
4. Model saving and inference capabilities

Run this script to see all recommendation approaches in action!
"""

import os
import sys
import pandas as pd
import numpy as np
import warnings
from pathlib import Path
import matplotlib.pyplot as plt

# Add src directory to path so we can import our modules
sys.path.append(str(Path(__file__).parent / "src"))

from data_preprocessing import MovieDataProcessor
from collaborative_filtering import UserBasedCollaborativeFilter
from content_based_filtering import ContentBasedRecommender
from hybrid_recommender import HybridRecommendationSystem, HybridStrategy, compare_hybrid_strategies
from evaluation_metrics import RecommendationEvaluator
from config.settings import *

warnings.filterwarnings('ignore')

# Configure matplotlib for better plots
plt.rcParams.update(PLOT_STYLE)


class MovieRecommendationPipeline:
    """
    Complete pipeline for movie recommendation system.
    
    This class coordinates all components and provides a unified interface
    for training, evaluation, and inference of recommendation models.
    """
    
    def __init__(self):
        self.processor = MovieDataProcessor()
        self.collaborative_filter = UserBasedCollaborativeFilter()
        self.content_recommender = ContentBasedRecommender()
        self.hybrid_system = HybridRecommendationSystem()
        self.evaluator = RecommendationEvaluator()
        
        self.processed_data = None
        self.is_trained = False
        
    def load_and_preprocess_data(self) -> None:
        """Load raw data and perform all preprocessing steps."""
        print("🎬 MOVIE RECOMMENDATION SYSTEM")
        print("=" * 80)
        print("📊 Step 1: Data Loading and Preprocessing")
        print("-" * 40)
        
        # Check if data files exist
        if not MOVIES_FILE.exists() or not RATINGS_FILE.exists():
            print("❌ Data files not found!")
            print(f"   Please ensure these files exist:")
            print(f"   - {MOVIES_FILE}")
            print(f"   - {RATINGS_FILE}")
            print("\n   You can download the MovieLens dataset from:")
            print("   https://grouplens.org/datasets/movielens/")
            return
        
        # Process all data
        self.processed_data = self.processor.process_all_data()
        
        # Print dataset summary
        metadata = self.processed_data['metadata']
        print(f"\n📈 Dataset Summary:")
        print(f"   👥 Users: {metadata['n_users']:,}")
        print(f"   🎬 Movies: {metadata['n_movies']:,}")
        print(f"   ⭐ Ratings: {metadata['n_ratings']:,}")
        print(f"   📊 Rating Range: {metadata['rating_range'][0]} - {metadata['rating_range'][1]}")
        
    def train_all_models(self) -> None:
        """Train all recommendation models."""
        if self.processed_data is None:
            raise ValueError("Data must be loaded first")
        
        print(f"\n🤖 Step 2: Model Training")
        print("-" * 40)
        
        train_data = {
            'collaborative': self.processed_data['collaborative'],
            'content_based': self.processed_data['content_based']
        }
        
        # Train collaborative filtering
        print("\n1️⃣ Training Collaborative Filtering Model...")
        self.collaborative_filter.fit(self.processed_data['collaborative']['train'])
        
        # Train content-based filtering
        print("\n2️⃣ Training Content-Based Model...")
        content_data = self.processed_data['content_based']
        self.content_recommender.fit(content_data['X_train'], content_data['y_train'])
        
        # Train hybrid system
        print("\n3️⃣ Training Hybrid System...")
        self.hybrid_system.fit(train_data)
        
        self.is_trained = True
        print("\n✅ All models trained successfully!")
        
    def evaluate_all_models(self) -> Dict:
        """Evaluate and compare all recommendation approaches."""
        if not self.is_trained:
            raise ValueError("Models must be trained first")
        
        print(f"\n📊 Step 3: Model Evaluation")
        print("-" * 40)
        
        test_data = {
            'collaborative': self.processed_data['collaborative'],
            'content_based': self.processed_data['content_based']
        }
        
        evaluation_results = {}
        
        # Evaluate collaborative filtering
        print("\n🤝 Evaluating Collaborative Filtering...")
        cf_predictions = self.collaborative_filter.predict(
            self.processed_data['collaborative']['test']
        )
        
        if not cf_predictions.empty:
            evaluation_results['collaborative'] = self.evaluator.evaluate_recommender_system(
                cf_predictions,
                self.processed_data['collaborative']['test'],
                system_name="Collaborative Filtering"
            )
        
        # Evaluate content-based filtering
        print("\n🤖 Evaluating Content-Based Filtering...")
        cb_predictions = self._get_content_predictions()
        
        if not cb_predictions.empty:
            evaluation_results['content_based'] = self.evaluator.evaluate_recommender_system(
                cb_predictions,
                self.processed_data['collaborative']['test'],
                system_name="Content-Based Filtering"
            )
        
        # Evaluate hybrid system
        print("\n🔀 Evaluating Hybrid System...")
        hybrid_predictions = self.hybrid_system.predict(test_data)
        
        if not hybrid_predictions.empty:
            evaluation_results['hybrid'] = self.evaluator.evaluate_recommender_system(
                hybrid_predictions,
                self.processed_data['collaborative']['test'],
                system_name="Hybrid System"
            )
        
        # Create comprehensive comparison
        print(f"\n📋 Step 4: Results Comparison")
        print("-" * 40)
        
        comparison_df = self.evaluator.compare_systems()
        if not comparison_df.empty:
            print("\n🏆 FINAL COMPARISON:")
            print(comparison_df.to_string(index=False))
            
            # Determine the best system
            if 'DSG@K' in comparison_df.columns:
                best_system = comparison_df.loc[
                    comparison_df['DSG@K'].str.replace('.', '').astype(float).idxmax(),
                    'System'
                ]
                print(f"\n🥇 Best performing system: {best_system}")
        
        return evaluation_results
    
    def _get_content_predictions(self) -> pd.DataFrame:
        """Helper to get content-based predictions in the right format."""
        content_data = self.processed_data['content_based']
        
        # Get predictions
        pred_values = self.content_recommender.predict(content_data['X_test'])
        
        # Create DataFrame with identifiers
        predictions_df = content_data['test_identifiers'].copy()
        predictions_df['prediction'] = pred_values
        
        return predictions_df
    
    def demonstrate_recommendations(self, user_id: int = None, n_recs: int = 5) -> None:
        """Show sample recommendations from different systems."""
        if not self.is_trained:
            print("⚠️  Models must be trained first")
            return
        
        # Pick a random user if none specified
        if user_id is None:
            available_users = self.processed_data['collaborative']['test']['userId'].unique()
            user_id = np.random.choice(available_users)
        
        print(f"\n🎯 Step 5: Sample Recommendations for User {user_id}")
        print("-" * 40)
        
        # Get collaborative filtering recommendations
        try:
            print(f"\n🤝 Collaborative Filtering Recommendations:")
            cf_recs = self.collaborative_filter.get_top_recommendations(user_id, n_recs)
            if cf_recs:
                for i, rec in enumerate(cf_recs, 1):
                    print(f"   {i}. Movie {rec['movieId']}: {rec['prediction']:.2f} stars")
            else:
                print("   ⚠️  No recommendations available (cold start problem)")
        except Exception as e:
            print(f"   ⚠️  Error: {e}")
        
        # Get hybrid recommendations
        try:
            print(f"\n🔀 Hybrid System Recommendations:")
            hybrid_recs = self.hybrid_system.get_recommendations(user_id, n_recs)
            if hybrid_recs:
                for i, rec in enumerate(hybrid_recs, 1):
                    print(f"   {i}. Movie {rec['movieId']}: {rec['prediction']:.2f} stars")
            else:
                print("   ⚠️  No recommendations available")
        except Exception as e:
            print(f"   ⚠️  Error: {e}")
    
    def save_models(self) -> None:
        """Save all trained models for later use."""
        if not self.is_trained:
            print("⚠️  No trained models to save")
            return
        
        print(f"\n💾 Saving Models...")
        
        # Save content-based model
        try:
            model_path = self.content_recommender.save_model()
            print(f"   ✅ Content-based model saved")
        except Exception as e:
            print(f"   ❌ Error saving content-based model: {e}")
        
        # Note: Collaborative filtering model doesn't need explicit saving
        # as it just stores correlations in memory
        print(f"   ℹ️  Collaborative model uses correlation matrix (no file save needed)")
    
    def run_complete_pipeline(self) -> None:
        """Run the entire recommendation system pipeline."""
        try:
            # Step 1: Load and preprocess data
            self.load_and_preprocess_data()
            
            if self.processed_data is None:
                return
            
            # Step 2: Train all models
            self.train_all_models()
            
            # Step 3: Evaluate models
            evaluation_results = self.evaluate_all_models()
            
            # Step 4: Show sample recommendations
            self.demonstrate_recommendations()
            
            # Step 5: Save models
            self.save_models()
            
            print(f"\n🎉 Pipeline Complete!")
            print(f"✅ All recommendation systems have been trained and evaluated")
            print(f"📊 Check the results above to see which approach works best")
            
        except Exception as e:
            print(f"\n❌ Pipeline failed: {e}")
            import traceback
            traceback.print_exc()


def run_advanced_analysis():
    """Run additional analysis like strategy comparison and weight optimization."""
    print(f"\n🔬 Advanced Analysis")
    print("=" * 50)
    
    # Load data
    processor = MovieDataProcessor()
    processed_data = processor.process_all_data()
    
    if processed_data is None:
        print("❌ Could not load data for advanced analysis")
        return
    
    train_data = {
        'collaborative': processed_data['collaborative'],
        'content_based': processed_data['content_based']
    }
    
    test_data = {
        'collaborative': processed_data['collaborative'],
        'content_based': processed_data['content_based']
    }
    
    # Compare different hybrid strategies
    print(f"\n🔄 Comparing Hybrid Strategies...")
    try:
        strategy_comparison = compare_hybrid_strategies(train_data, test_data)
        if not strategy_comparison.empty:
            print("\n📊 Strategy Comparison Results:")
            print(strategy_comparison.to_string(index=False))
    except Exception as e:
        print(f"   ❌ Error in strategy comparison: {e}")


def create_simple_inference_system():
    """Create a simple system for making predictions on new data."""
    
    def predict_rating(user_features: dict, movie_features: dict) -> float:
        """
        Simple prediction function that mimics the trained models.
        
        In a real system, you'd load the saved models and use them for prediction.
        This is a simplified version for demonstration.
        
        Args:
            user_features: Dictionary with user characteristics
            movie_features: Dictionary with movie characteristics
            
        Returns:
            Predicted rating
        """
        # This is a very simplified prediction logic
        # In practice, you'd use the trained CatBoost model
        
        base_rating = user_features.get('userMeans', 3.5)
        
        # Adjust based on genre preferences (simplified)
        genre_adjustment = 0
        if movie_features.get('Action', 0) and user_features.get('likes_action', True):
            genre_adjustment += 0.3
        if movie_features.get('Comedy', 0) and user_features.get('likes_comedy', True):
            genre_adjustment += 0.2
        
        # Adjust based on movie year
        movie_year = movie_features.get('movieYear', 2000)
        if movie_year > 2015:  # Newer movies might be rated higher
            genre_adjustment += 0.1
        
        predicted_rating = base_rating + genre_adjustment
        
        # Ensure rating is in valid range
        return max(0.5, min(5.0, predicted_rating))
    
    # Example usage
    sample_user = {
        'userMeans': 4.2,
        'userViews': 25,
        'likes_action': True,
        'likes_comedy': False
    }
    
    sample_movie = {
        'movieYear': 2020,
        'Action': 1,
        'Comedy': 0,
        'Drama': 1
    }
    
    prediction = predict_rating(sample_user, sample_movie)
    
    print(f"\n🎯 Simple Inference Example:")
    print(f"   User profile: {sample_user}")
    print(f"   Movie features: {sample_movie}")
    print(f"   Predicted rating: {prediction:.2f}")
    print(f"\n   Note: This is a simplified example.")
    print(f"   In production, you'd load the trained CatBoost model.")


def main():
    """Main function that runs the complete recommendation system."""
    print("🚀 STARTING MOVIE RECOMMENDATION SYSTEM")
    print("=" * 80)
    
    # Create and run the pipeline
    pipeline = MovieRecommendationPipeline()
    pipeline.run_complete_pipeline()
    
    # Run advanced analysis
    print(f"\n" + "=" * 80)
    run_advanced_analysis()
    
    # Show simple inference example
    print(f"\n" + "=" * 80)
    create_simple_inference_system()
    
    print(f"\n🎬 Thank you for using the Movie Recommendation System!")
    print(f"📚 Check the documentation in each module for more details.")


if __name__ == "__main__":
    main()