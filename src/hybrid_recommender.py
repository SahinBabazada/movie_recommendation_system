"""
Hybrid Recommendation System.

This module combines collaborative filtering and content-based approaches
to leverage the strengths of both methods. Collaborative filtering excels
at finding hidden patterns in user behavior, while content-based filtering
handles cold start problems and provides explainable recommendations.

The hybrid approach can use different combination strategies:
- Weighted average of predictions
- Switching between methods based on confidence
- Mixed recommendations from both systems
"""

import pandas as pd
import numpy as np
import warnings
from typing import Dict, List, Tuple, Optional, Union
from enum import Enum

from collaborative_filtering import UserBasedCollaborativeFilter
from content_based_filtering import ContentBasedRecommender
from evaluation_metrics import RecommendationEvaluator

warnings.filterwarnings('ignore')


class HybridStrategy(Enum):
    """Different strategies for combining recommendations."""
    WEIGHTED = "weighted"          # Weighted average of predictions
    SWITCHING = "switching"        # Switch based on confidence/coverage
    MIXED = "mixed"               # Mix recommendations from both systems
    CASCADE = "cascade"           # Use second system to refine first system's output


class HybridRecommendationSystem:
    """
    A hybrid recommendation system combining collaborative and content-based filtering.
    
    This system intelligently combines two different recommendation approaches:
    1. Collaborative Filtering: "Users like you also enjoyed..."
    2. Content-Based Filtering: "Because you liked X, you might like Y..."
    
    The hybrid approach helps overcome individual limitations:
    - CF struggles with new users/items (cold start)
    - CB may lack serendipity and gets stuck in filter bubbles
    - Hybrid systems provide better coverage and accuracy
    """
    
    def __init__(self, 
                 collaborative_weight: float = 0.6,
                 content_weight: float = 0.4,
                 strategy: HybridStrategy = HybridStrategy.WEIGHTED,
                 min_cf_confidence: float = 0.5):
        """
        Initialize the hybrid recommendation system.
        
        Args:
            collaborative_weight: Weight for collaborative filtering predictions
            content_weight: Weight for content-based predictions
            strategy: How to combine the two approaches
            min_cf_confidence: Minimum confidence threshold for using CF predictions
        """
        # Validate weights
        if abs(collaborative_weight + content_weight - 1.0) > 1e-6:
            print("⚠️  Weights don't sum to 1.0, normalizing...")
            total = collaborative_weight + content_weight
            collaborative_weight /= total
            content_weight /= total
        
        self.collaborative_weight = collaborative_weight
        self.content_weight = content_weight
        self.strategy = strategy
        self.min_cf_confidence = min_cf_confidence
        
        # Initialize component systems
        self.collaborative_filter = UserBasedCollaborativeFilter()
        self.content_recommender = ContentBasedRecommender()
        
        self.is_fitted = False
        
        print(f"🔀 Initialized Hybrid System:")
        print(f"   Strategy: {strategy.value}")
        print(f"   Weights: CF={collaborative_weight:.1f}, CB={content_weight:.1f}")
    
    def fit(self, train_data: Dict) -> None:
        """
        Train both collaborative and content-based components.
        
        Args:
            train_data: Dictionary containing training data for both systems
                       Must have keys: 'collaborative' and 'content_based'
        """
        print("🚀 Training hybrid recommendation system...")
        print("=" * 50)
        
        # Train collaborative filtering component
        print("1️⃣ Training Collaborative Filter...")
        collab_train = train_data['collaborative']['train']
        self.collaborative_filter.fit(collab_train)
        
        print("\n2️⃣ Training Content-Based Recommender...")
        content_train = train_data['content_based']
        self.content_recommender.fit(
            content_train['X_train'], 
            content_train['y_train']
        )
        
        self.is_fitted = True
        print("\n✅ Hybrid system training complete!")
    
    def predict(self, test_data: Dict) -> pd.DataFrame:
        """
        Generate hybrid predictions by combining both approaches.
        
        Args:
            test_data: Dictionary with test data for both systems
            
        Returns:
            DataFrame with hybrid predictions
        """
        if not self.is_fitted:
            raise ValueError("System must be fitted before making predictions")
        
        print(f"🔮 Generating hybrid predictions using {self.strategy.value} strategy...")
        
        # Get predictions from both systems
        print("   📊 Getting collaborative filtering predictions...")
        cf_predictions = self.collaborative_filter.predict(
            test_data['collaborative']['test']
        )
        
        print("   🤖 Getting content-based predictions...")
        cb_predictions = self._get_content_based_predictions(test_data['content_based'])
        
        # Combine predictions based on strategy
        if self.strategy == HybridStrategy.WEIGHTED:
            hybrid_predictions = self._weighted_combination(cf_predictions, cb_predictions)
        elif self.strategy == HybridStrategy.SWITCHING:
            hybrid_predictions = self._switching_combination(cf_predictions, cb_predictions)
        elif self.strategy == HybridStrategy.MIXED:
            hybrid_predictions = self._mixed_combination(cf_predictions, cb_predictions)
        elif self.strategy == HybridStrategy.CASCADE:
            hybrid_predictions = self._cascade_combination(cf_predictions, cb_predictions)
        else:
            raise ValueError(f"Unknown strategy: {self.strategy}")
        
        print(f"   ✅ Generated {len(hybrid_predictions)} hybrid predictions")
        
        return hybrid_predictions
    
    def _get_content_based_predictions(self, content_data: Dict) -> pd.DataFrame:
        """Get predictions from the content-based system in the right format."""
        X_test = content_data['X_test']
        test_identifiers = content_data['test_identifiers']
        
        # Get predictions
        cb_pred_values = self.content_recommender.predict(X_test)
        
        # Create DataFrame in the same format as collaborative predictions
        cb_predictions = test_identifiers.copy()
        cb_predictions['prediction'] = cb_pred_values
        
        return cb_predictions
    
    def _weighted_combination(self, cf_preds: pd.DataFrame, 
                            cb_preds: pd.DataFrame) -> pd.DataFrame:
        """
        Combine predictions using weighted average.
        
        This is the most straightforward approach - simply take a weighted
        average of the two prediction scores.
        """
        print("   ⚖️  Using weighted combination...")
        
        # Merge predictions on user-movie pairs
        merged = pd.merge(
            cf_preds[['userId', 'movieId', 'prediction', 'rating']],
            cb_preds[['userId', 'movieId', 'prediction']],
            on=['userId', 'movieId'],
            how='outer',
            suffixes=('_cf', '_cb')
        )
        
        # Fill missing predictions with the other system's prediction
        merged['prediction_cf'] = merged['prediction_cf'].fillna(merged['prediction_cb'])
        merged['prediction_cb'] = merged['prediction_cb'].fillna(merged['prediction_cf'])
        
        # Calculate weighted average
        merged['prediction'] = (
            self.collaborative_weight * merged['prediction_cf'] + 
            self.content_weight * merged['prediction_cb']
        )
        
        # Keep only rows where we have actual ratings (from test set)
        result = merged[merged['rating'].notna()][
            ['userId', 'movieId', 'prediction', 'rating']
        ].copy()
        
        return result
    
    def _switching_combination(self, cf_preds: pd.DataFrame, 
                             cb_preds: pd.DataFrame) -> pd.DataFrame:
        """
        Switch between systems based on confidence.
        
        Use collaborative filtering when we have confident predictions
        (many neighbors), otherwise fall back to content-based.
        """
        print("   🔄 Using switching combination...")
        
        # Start with content-based predictions as baseline
        merged = pd.merge(
            cb_preds[['userId', 'movieId', 'prediction', 'rating']],
            cf_preds[['userId', 'movieId', 'prediction', 'n_neighbors']],
            on=['userId', 'movieId'],
            how='left',
            suffixes=('_cb', '_cf')
        )
        
        # Switch to CF predictions when we have enough neighbors
        high_confidence_mask = (
            merged['n_neighbors'].notna() & 
            (merged['n_neighbors'] >= 3)  # Need at least 3 neighbors for confidence
        )
        
        merged['prediction'] = merged['prediction_cb']  # Start with CB
        merged.loc[high_confidence_mask, 'prediction'] = merged.loc[high_confidence_mask, 'prediction_cf']
        
        # Track which system was used
        merged['system_used'] = 'content_based'
        merged.loc[high_confidence_mask, 'system_used'] = 'collaborative'
        
        result = merged[['userId', 'movieId', 'prediction', 'rating', 'system_used']].copy()
        
        print(f"      📊 Used CF for {high_confidence_mask.sum()} predictions")
        print(f"      📊 Used CB for {(~high_confidence_mask).sum()} predictions")
        
        return result
    
    def _mixed_combination(self, cf_preds: pd.DataFrame, 
                          cb_preds: pd.DataFrame) -> pd.DataFrame:
        """
        Create mixed recommendations by taking top items from both systems.
        
        This approach provides diversity by ensuring both systems
        contribute to the final recommendations.
        """
        print("   🎭 Using mixed combination...")
        
        mixed_results = []
        
        # Process each user separately
        all_users = set(cf_preds['userId'].unique()) | set(cb_preds['userId'].unique())
        
        for user_id in all_users:
            # Get predictions from both systems for this user
            user_cf = cf_preds[cf_preds['userId'] == user_id].copy()
            user_cb = cb_preds[cb_preds['userId'] == user_id].copy()
            
            # Sort by prediction score
            user_cf = user_cf.sort_values('prediction', ascending=False)
            user_cb = user_cb.sort_values('prediction', ascending=False)
            
            # Take alternating recommendations (CF first, then CB, then CF, etc.)
            mixed_user_recs = []
            max_recs = max(len(user_cf), len(user_cb))
            
            for i in range(max_recs):
                # Add CF recommendation if available
                if i < len(user_cf):
                    rec = user_cf.iloc[i].copy()
                    rec['source_system'] = 'collaborative'
                    mixed_user_recs.append(rec)
                
                # Add CB recommendation if available and not duplicate
                if i < len(user_cb):
                    cb_rec = user_cb.iloc[i]
                    # Avoid duplicates
                    if cb_rec['movieId'] not in [r['movieId'] for r in mixed_user_recs]:
                        rec = cb_rec.copy()
                        rec['source_system'] = 'content_based'
                        mixed_user_recs.append(rec)
            
            if mixed_user_recs:
                mixed_results.extend(mixed_user_recs)
        
        if mixed_results:
            result = pd.DataFrame(mixed_results)
            result = result[result['rating'].notna()]  # Only keep items with actual ratings
        else:
            result = pd.DataFrame()
        
        return result
    
    def _cascade_combination(self, cf_preds: pd.DataFrame, 
                           cb_preds: pd.DataFrame) -> pd.DataFrame:
        """
        Use content-based system to refine collaborative filtering results.
        
        Start with CF predictions, then use CB to re-rank or filter them.
        """
        print("   📚 Using cascade combination...")
        
        # Start with collaborative filtering predictions
        result = cf_preds.copy()
        
        # Get content-based scores for the same user-movie pairs
        cb_lookup = cb_preds.set_index(['userId', 'movieId'])['prediction']
        
        # Add CB scores where available
        result['cb_score'] = result.apply(
            lambda row: cb_lookup.get((row['userId'], row['movieId']), 3.0), 
            axis=1
        )
        
        # Re-weight CF predictions based on CB agreement
        # If both systems agree (both high or both low), boost confidence
        # If they disagree, reduce confidence
        result['agreement'] = 1 - abs(result['prediction'] - result['cb_score']) / 4.0
        result['prediction'] = (
            result['prediction'] * result['agreement'] + 
            result['cb_score'] * (1 - result['agreement'])
        )
        
        return result[['userId', 'movieId', 'prediction', 'rating']]
    
    def get_recommendations(self, user_id: int, n_recommendations: int = 10,
                          exclude_seen: bool = True) -> List[Dict]:
        """
        Get personalized recommendations for a user using the hybrid approach.
        
        Args:
            user_id: Target user ID
            n_recommendations: Number of recommendations to return
            exclude_seen: Whether to exclude movies the user has already rated
            
        Returns:
            List of recommended movies with scores and explanations
        """
        if not self.is_fitted:
            raise ValueError("System must be fitted before making recommendations")
        
        print(f"🎯 Generating {n_recommendations} recommendations for user {user_id}...")
        
        recommendations = []
        
        try:
            # Get recommendations from collaborative filtering
            cf_recs = self.collaborative_filter.get_top_recommendations(
                user_id, n_recommendations * 2, exclude_seen
            )
            
            # For content-based recommendations, we'd need user profile
            # This is simplified - in practice, you'd build user profile from their history
            
            # Combine and rank recommendations
            for rec in cf_recs[:n_recommendations]:
                rec['source'] = 'hybrid'
                rec['cf_score'] = rec['prediction']
                recommendations.append(rec)
        
        except Exception as e:
            print(f"   ⚠️  Error generating recommendations: {e}")
            return []
        
        return recommendations
    
    def explain_recommendation(self, user_id: int, movie_id: int) -> Dict:
        """
        Provide explanation for why a movie was recommended.
        
        Args:
            user_id: User ID
            movie_id: Movie ID
            
        Returns:
            Dictionary with explanation from both systems
        """
        explanation = {
            'user_id': user_id,
            'movie_id': movie_id,
            'hybrid_strategy': self.strategy.value,
            'explanations': {}
        }
        
        # Get explanation from collaborative filtering
        try:
            cf_explanation = self.collaborative_filter.explain_recommendation(user_id, movie_id)
            explanation['explanations']['collaborative'] = cf_explanation
        except Exception as e:
            explanation['explanations']['collaborative'] = {'error': str(e)}
        
        # Content-based explanation would require feature analysis
        explanation['explanations']['content_based'] = {
            'note': 'Content-based explanations require feature analysis implementation'
        }
        
        return explanation
    
    def evaluate_components(self, test_data: Dict) -> Dict[str, Dict]:
        """
        Evaluate individual components and the hybrid system.
        
        Args:
            test_data: Test data for evaluation
            
        Returns:
            Dictionary with evaluation results for each component
        """
        print("🔬 Evaluating hybrid system components...")
        
        evaluator = RecommendationEvaluator()
        results = {}
        
        # Evaluate collaborative filtering
        cf_predictions = self.collaborative_filter.predict(test_data['collaborative']['test'])
        if not cf_predictions.empty:
            results['collaborative'] = evaluator.evaluate_recommender_system(
                cf_predictions, 
                test_data['collaborative']['test'],
                system_name="Collaborative Filtering"
            )
        
        # Evaluate content-based filtering
        cb_predictions = self._get_content_based_predictions(test_data['content_based'])
        if not cb_predictions.empty:
            results['content_based'] = evaluator.evaluate_recommender_system(
                cb_predictions,
                test_data['collaborative']['test'],  # Use same test reference
                system_name="Content-Based Filtering"
            )
        
        # Evaluate hybrid system
        hybrid_predictions = self.predict(test_data)
        if not hybrid_predictions.empty:
            results['hybrid'] = evaluator.evaluate_recommender_system(
                hybrid_predictions,
                test_data['collaborative']['test'],
                system_name=f"Hybrid ({self.strategy.value})"
            )
        
        # Create comparison
        comparison_df = evaluator.compare_systems()
        results['comparison'] = comparison_df
        
        return results


def compare_hybrid_strategies(train_data: Dict, test_data: Dict) -> pd.DataFrame:
    """
    Compare different hybrid combination strategies.
    
    Args:
        train_data: Training data
        test_data: Test data
        
    Returns:
        DataFrame comparing strategy performance
    """
    print("🔄 Comparing hybrid strategies...")
    
    strategies = [
        HybridStrategy.WEIGHTED,
        HybridStrategy.SWITCHING,
        HybridStrategy.MIXED,
        HybridStrategy.CASCADE
    ]
    
    evaluator = RecommendationEvaluator()
    
    for strategy in strategies:
        print(f"\n🧪 Testing {strategy.value} strategy...")
        
        # Create hybrid system with this strategy
        hybrid_system = HybridRecommendationSystem(strategy=strategy)
        hybrid_system.fit(train_data)
        
        # Generate predictions
        predictions = hybrid_system.predict(test_data)
        
        if not predictions.empty:
            # Evaluate this strategy
            evaluator.evaluate_recommender_system(
                predictions,
                test_data['collaborative']['test'],
                system_name=f"Hybrid-{strategy.value}"
            )