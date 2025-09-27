"""
Movie Recommendation System Package

This package provides a comprehensive movie recommendation system with multiple approaches:
- Collaborative Filtering: User-based recommendations using correlation
- Content-Based Filtering: Feature-based recommendations using machine learning
- Hybrid Systems: Combining multiple approaches for better performance

Main Components:
- data_preprocessing: Data loading and feature engineering
- collaborative_filtering: User-based collaborative filtering implementation
- content_based_filtering: Content-based filtering using CatBoost
- hybrid_recommender: Hybrid system combining multiple approaches
- evaluation_metrics: Comprehensive evaluation and comparison tools

Example Usage:
    from src.data_preprocessing import MovieDataProcessor
    from src.hybrid_recommender import HybridRecommendationSystem
    
    # Load and process data
    processor = MovieDataProcessor()
    data = processor.process_all_data()
    
    # Train hybrid system
    hybrid = HybridRecommendationSystem()
    hybrid.fit(data)
    
    # Get recommendations
    recommendations = hybrid.get_recommendations(user_id=123, n_recommendations=10)
"""

__version__ = "1.0.0"
__author__ = "Movie Recommendation System Team"
__email__ = "contact@movierecsys.com"

# Import main classes for easy access
from .data_preprocessing import MovieDataProcessor
from .collaborative_filtering import UserBasedCollaborativeFilter
from .content_based_filtering import ContentBasedRecommender
from .hybrid_recommender import HybridRecommendationSystem, HybridStrategy
from .evaluation_metrics import RecommendationEvaluator

__all__ = [
    'MovieDataProcessor',
    'UserBasedCollaborativeFilter', 
    'ContentBasedRecommender',
    'HybridRecommendationSystem',
    'HybridStrategy',
    'RecommendationEvaluator'
]