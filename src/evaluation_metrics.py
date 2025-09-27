"""
Evaluation metrics for recommendation systems.

This module implements various metrics to assess how well our recommenders
are performing, including ranking-based metrics like DSG (Discounted 
Cumulative Gain) and rating prediction accuracy metrics.

DSG@K is particularly important because it considers both relevance and
ranking position - items ranked higher should be more relevant.
"""

import pandas as pd
import numpy as np
import warnings
from typing import Dict, List, Tuple, Optional
from collections import defaultdict

from config.settings import DSG_K

warnings.filterwarnings('ignore')


class RecommendationEvaluator:
    """
    Comprehensive evaluation suite for recommendation systems.
    
    Provides both rating prediction metrics (how accurate are our ratings?)
    and ranking metrics (how good is our recommendation order?).
    """
    
    def __init__(self):
        self.evaluation_results = {}
    
    def calculate_dsg_at_k(self, predictions_df: pd.DataFrame, 
                          k: int = DSG_K, 
                          rating_column: str = 'rating',
                          prediction_column: str = 'prediction',
                          user_column: str = 'userId') -> float:
        """
        Calculate Discounted Cumulative Gain at K (DSG@K).
        
        DSG@K measures how well we rank items by considering both relevance
        (actual rating) and position (items ranked higher count more).
        
        Formula for each user:
        DSG@K = sum(relevance_i / log2(position_i + 1)) for i in top_k_items
        
        Args:
            predictions_df: DataFrame with user predictions and actual ratings
            k: Number of top items to consider
            rating_column: Column name for actual ratings (relevance)
            prediction_column: Column name for predicted ratings
            user_column: Column name for user IDs
            
        Returns:
            Average DSG@K across all users
        """
        print(f"📊 Calculating DSG@{k}...")
        
        user_dsg_scores = []
        users_processed = 0
        
        # Calculate DSG@K for each user individually
        for user_id in predictions_df[user_column].unique():
            user_data = predictions_df[predictions_df[user_column] == user_id]
            
            if len(user_data) == 0:
                continue
            
            # Sort items by predicted rating (descending - best first)
            sorted_items = user_data.sort_values(prediction_column, ascending=False)
            
            # Take only top K items
            top_k_items = sorted_items.head(k)
            
            # Calculate DSG for this user
            user_dsg = 0.0
            for position, (_, item) in enumerate(top_k_items.iterrows()):
                # Position starts from 1 (not 0)
                discount_factor = np.log2(position + 2)  # +2 because position starts from 0
                relevance = item[rating_column]
                
                user_dsg += relevance / discount_factor
            
            user_dsg_scores.append(user_dsg)
            users_processed += 1
        
        if not user_dsg_scores:
            print("   ⚠️  No valid users for DSG calculation")
            return 0.0
        
        avg_dsg = np.mean(user_dsg_scores)
        print(f"   ✅ Average DSG@{k}: {avg_dsg:.4f} (across {users_processed} users)")
        
        return avg_dsg
    
    def calculate_rating_metrics(self, y_true: np.ndarray, 
                               y_pred: np.ndarray) -> Dict[str, float]:
        """
        Calculate standard regression metrics for rating prediction.
        
        Args:
            y_true: True ratings
            y_pred: Predicted ratings
            
        Returns:
            Dictionary of metric values
        """
        print("📈 Calculating rating prediction metrics...")
        
        # Root Mean Squared Error
        rmse = np.sqrt(np.mean((y_true - y_pred) ** 2))
        
        # Mean Absolute Error
        mae = np.mean(np.abs(y_true - y_pred))
        
        # Mean Squared Error
        mse = np.mean((y_true - y_pred) ** 2)
        
        # R-squared (coefficient of determination)
        ss_res = np.sum((y_true - y_pred) ** 2)
        ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
        r2 = 1 - (ss_res / ss_tot) if ss_tot != 0 else 0
        
        # Mean Absolute Percentage Error
        mape = np.mean(np.abs((y_true - y_pred) / y_true)) * 100
        
        metrics = {
            'rmse': rmse,
            'mae': mae,
            'mse': mse,
            'r2': r2,
            'mape': mape
        }
        
        print(f"   📊 RMSE: {rmse:.4f}")
        print(f"   📊 MAE:  {mae:.4f}")
        print(f"   📊 R²:   {r2:.4f}")
        print(f"   📊 MAPE: {mape:.2f}%")
        
        return metrics
    
    def calculate_coverage_metrics(self, predictions_df: pd.DataFrame,
                                 test_df: pd.DataFrame,
                                 user_column: str = 'userId',
                                 item_column: str = 'movieId') -> Dict[str, float]:
        """
        Calculate coverage metrics - how much of the test set we can predict.
        
        Args:
            predictions_df: DataFrame with predictions
            test_df: Original test dataset
            user_column: Column name for user IDs
            item_column: Column name for item IDs
            
        Returns:
            Dictionary of coverage metrics
        """
        print("🎯 Calculating coverage metrics...")
        
        # User coverage: percentage of test users we can make predictions for
        test_users = set(test_df[user_column].unique())
        pred_users = set(predictions_df[user_column].unique())
        user_coverage = len(pred_users) / len(test_users) if test_users else 0
        
        # Item coverage: percentage of test items we can predict
        test_items = set(test_df[item_column].unique())
        pred_items = set(predictions_df[item_column].unique())
        item_coverage = len(pred_items) / len(test_items) if test_items else 0
        
        # Overall coverage: percentage of test interactions we can predict
        test_pairs = len(test_df)
        pred_pairs = len(predictions_df)
        overall_coverage = pred_pairs / test_pairs if test_pairs else 0
        
        coverage_metrics = {
            'user_coverage': user_coverage,
            'item_coverage': item_coverage,
            'overall_coverage': overall_coverage,
            'predicted_interactions': pred_pairs,
            'total_test_interactions': test_pairs
        }
        
        print(f"   👥 User coverage: {user_coverage:.1%}")
        print(f"   🎬 Item coverage: {item_coverage:.1%}")
        print(f"   🎯 Overall coverage: {overall_coverage:.1%}")
        
        return coverage_metrics
    
    def calculate_diversity_metrics(self, recommendations_df: pd.DataFrame,
                                  movie_features_df: pd.DataFrame,
                                  user_column: str = 'userId',
                                  item_column: str = 'movieId') -> Dict[str, float]:
        """
        Calculate recommendation diversity - how varied are our recommendations?
        
        Diversity is important to avoid filter bubbles and provide 
        users with a good variety of content.
        
        Args:
            recommendations_df: DataFrame with user recommendations
            movie_features_df: DataFrame with movie features (genres, etc.)
            user_column: Column name for user IDs
            item_column: Column name for item IDs
            
        Returns:
            Dictionary of diversity metrics
        """
        print("🌈 Calculating diversity metrics...")
        
        # Merge recommendations with movie features
        rec_with_features = pd.merge(
            recommendations_df,
            movie_features_df,
            on=item_column,
            how='left'
        )
        
        # Calculate genre diversity for each user
        genre_columns = [col for col in rec_with_features.columns 
                        if col in ['Adventure', 'Comedy', 'Action', 'Mystery', 
                                  'Crime', 'Thriller', 'Drama', 'Animation', 
                                  'Children', 'Horror', 'Documentary', 'Sci-Fi', 
                                  'Fantasy', 'Film-Noir', 'Western', 'Musical', 
                                  'Romance', 'War']]
        
        user_diversity_scores = []
        
        for user_id in rec_with_features[user_column].unique():
            user_recs = rec_with_features[rec_with_features[user_column] == user_id]
            
            if len(user_recs) == 0:
                continue
            
            # Count genres in user's recommendations
            genre_counts = user_recs[genre_columns].sum()
            
            # Calculate Shannon diversity index
            total_genres = genre_counts.sum()
            if total_genres > 0:
                genre_proportions = genre_counts / total_genres
                # Only consider genres that are actually present
                non_zero_proportions = genre_proportions[genre_proportions > 0]
                
                # Shannon diversity: -sum(p * log(p))
                shannon_diversity = -np.sum(non_zero_proportions * np.log(non_zero_proportions))
                user_diversity_scores.append(shannon_diversity)
        
        diversity_metrics = {
            'avg_shannon_diversity': np.mean(user_diversity_scores) if user_diversity_scores else 0,
            'std_shannon_diversity': np.std(user_diversity_scores) if user_diversity_scores else 0,
            'users_with_diverse_recs': len([d for d in user_diversity_scores if d > 1.0])
        }
        
        print(f"   🌈 Average Shannon diversity: {diversity_metrics['avg_shannon_diversity']:.3f}")
        print(f"   📊 Users with diverse recommendations: {diversity_metrics['users_with_diverse_recs']}")
        
        return diversity_metrics
    
    def evaluate_recommender_system(self, 
                                  predictions_df: pd.DataFrame,
                                  test_df: pd.DataFrame,
                                  movie_features_df: pd.DataFrame = None,
                                  system_name: str = "Recommender") -> Dict[str, Dict]:
        """
        Comprehensive evaluation of a recommendation system.
        
        Args:
            predictions_df: DataFrame with system predictions
            test_df: Test dataset with true ratings
            movie_features_df: Optional movie features for diversity analysis
            system_name: Name of the system being evaluated
            
        Returns:
            Dictionary containing all evaluation results
        """
        print(f"\n🔬 Evaluating {system_name}")
        print("=" * 60)
        
        evaluation_results = {
            'system_name': system_name,
            'n_predictions': len(predictions_df),
            'n_test_samples': len(test_df)
        }
        
        # 1. DSG@K metric (ranking quality)
        if 'prediction' in predictions_df.columns and 'rating' in predictions_df.columns:
            dsg_score = self.calculate_dsg_at_k(predictions_df)
            evaluation_results['ranking'] = {'dsg_at_k': dsg_score}
        
        # 2. Rating prediction accuracy
        if 'prediction' in predictions_df.columns and 'rating' in predictions_df.columns:
            rating_metrics = self.calculate_rating_metrics(
                predictions_df['rating'].values,
                predictions_df['prediction'].values
            )
            evaluation_results['rating_accuracy'] = rating_metrics
        
        # 3. Coverage analysis
        coverage_metrics = self.calculate_coverage_metrics(predictions_df, test_df)
        evaluation_results['coverage'] = coverage_metrics
        
        # 4. Diversity analysis (if movie features provided)
        if movie_features_df is not None:
            diversity_metrics = self.calculate_diversity_metrics(
                predictions_df, movie_features_df
            )
            evaluation_results['diversity'] = diversity_metrics
        
        # Store results for comparison
        self.evaluation_results[system_name] = evaluation_results
        
        print("=" * 60)
        print(f"✅ Evaluation complete for {system_name}")
        
        return evaluation_results
    
    def compare_systems(self, system_names: List[str] = None) -> pd.DataFrame:
        """
        Compare multiple recommendation systems side by side.
        
        Args:
            system_names: List of system names to compare (all if None)
            
        Returns:
            DataFrame with comparison metrics
        """
        if not self.evaluation_results:
            print("⚠️  No evaluation results available for comparison")
            return pd.DataFrame()
        
        if system_names is None:
            system_names = list(self.evaluation_results.keys())
        
        print(f"\n📊 Comparing {len(system_names)} systems...")
        
        comparison_data = []
        
        for system_name in system_names:
            if system_name not in self.evaluation_results:
                print(f"   ⚠️  No results found for {system_name}")
                continue
            
            results = self.evaluation_results[system_name]
            
            row = {'System': system_name}
            
            # Add ranking metrics
            if 'ranking' in results:
                row['DSG@K'] = f"{results['ranking']['dsg_at_k']:.4f}"
            
            # Add accuracy metrics
            if 'rating_accuracy' in results:
                row['RMSE'] = f"{results['rating_accuracy']['rmse']:.4f}"
                row['MAE'] = f"{results['rating_accuracy']['mae']:.4f}"
                row['R²'] = f"{results['rating_accuracy']['r2']:.4f}"
            
            # Add coverage metrics
            if 'coverage' in results:
                row['Coverage'] = f"{results['coverage']['overall_coverage']:.1%}"
                row['User Coverage'] = f"{results['coverage']['user_coverage']:.1%}"
            
            # Add diversity metrics
            if 'diversity' in results:
                row['Diversity'] = f"{results['diversity']['avg_shannon_diversity']:.3f}"
            
            comparison_data.append(row)
        
        comparison_df = pd.DataFrame(comparison_data)
        
        if not comparison_df.empty:
            print("\n📋 System Comparison:")
            print(comparison_df.to_string(index=False))
        
        return comparison_df
    
    def plot_evaluation_results(self, system_names: List[str] = None,
                              save_path: str = None) -> None:
        """
        Create visualizations of evaluation results.
        
        Args:
            system_names: Systems to include in plots
            save_path: Path to save plots (optional)
        """
        try:
            import matplotlib.pyplot as plt
            import seaborn as sns
        except ImportError:
            print("⚠️  Matplotlib/Seaborn not available for plotting")
            return
        
        if not self.evaluation_results:
            print("⚠️  No evaluation results available for plotting")
            return
        
        if system_names is None:
            system_names = list(self.evaluation_results.keys())
        
        # Set up the plotting style
        plt.style.use('default')
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle('Recommendation System Evaluation', fontsize=16, fontweight='bold')
        
        # Collect data for plotting
        plot_data = defaultdict(list)
        
        for system_name in system_names:
            if system_name not in self.evaluation_results:
                continue
            
            results = self.evaluation_results[system_name]
            plot_data['systems'].append(system_name)
            
            # DSG scores
            if 'ranking' in results:
                plot_data['dsg'].append(results['ranking']['dsg_at_k'])
            else:
                plot_data['dsg'].append(0)
            
            # RMSE scores
            if 'rating_accuracy' in results:
                plot_data['rmse'].append(results['rating_accuracy']['rmse'])
            else:
                plot_data['rmse'].append(0)
            
            # Coverage scores
            if 'coverage' in results:
                plot_data['coverage'].append(results['coverage']['overall_coverage'])
            else:
                plot_data['coverage'].append(0)
            
            # Diversity scores
            if 'diversity' in results:
                plot_data['diversity'].append(results['diversity']['avg_shannon_diversity'])
            else:
                plot_data['diversity'].append(0)
        
        # Plot 1: DSG@K scores
        if plot_data['dsg']:
            axes[0, 0].bar(plot_data['systems'], plot_data['dsg'], color='skyblue')
            axes[0, 0].set_title('DSG@K Scores (Higher = Better)')
            axes[0, 0].set_ylabel('DSG@K')
            axes[0, 0].tick_params(axis='x', rotation=45)
        
        # Plot 2: RMSE scores
        if plot_data['rmse']:
            axes[0, 1].bar(plot_data['systems'], plot_data['rmse'], color='lightcoral')
            axes[0, 1].set_title('RMSE Scores (Lower = Better)')
            axes[0, 1].set_ylabel('RMSE')
            axes[0, 1].tick_params(axis='x', rotation=45)
        
        # Plot 3: Coverage
        if plot_data['coverage']:
            axes[1, 0].bar(plot_data['systems'], [c * 100 for c in plot_data['coverage']], 
                          color='lightgreen')
            axes[1, 0].set_title('Coverage % (Higher = Better)')
            axes[1, 0].set_ylabel('Coverage %')
            axes[1, 0].tick_params(axis='x', rotation=45)
        
        # Plot 4: Diversity
        if plot_data['diversity']:
            axes[1, 1].bar(plot_data['systems'], plot_data['diversity'], color='gold')
            axes[1, 1].set_title('Shannon Diversity (Higher = Better)')
            axes[1, 1].set_ylabel('Diversity Score')
            axes[1, 1].tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"   💾 Plots saved to: {save_path}")
        
        plt.show()


def calculate_precision_at_k(recommendations_df: pd.DataFrame,
                           relevant_items_df: pd.DataFrame,
                           k: int = 10,
                           relevance_threshold: float = 4.0) -> float:
    """
    Calculate Precision@K - what fraction of recommended items are relevant?
    
    Args:
        recommendations_df: DataFrame with user recommendations
        relevant_items_df: DataFrame with items users actually liked
        k: Number of top recommendations to consider
        relevance_threshold: Minimum rating to consider item as relevant
        
    Returns:
        Average Precision@K across all users
    """
    print(f"🎯 Calculating Precision@{k}...")
    
    # Define relevant items (those with high ratings)
    relevant_items = relevant_items_df[
        relevant_items_df['rating'] >= relevance_threshold
    ]
    
    user_precisions = []
    
    for user_id in recommendations_df['userId'].unique():
        # Get top-k recommendations for this user
        user_recs = recommendations_df[
            recommendations_df['userId'] == user_id
        ].head(k)
        
        # Get relevant items for this user
        user_relevant = relevant_items[
            relevant_items['userId'] == user_id
        ]['movieId'].tolist()
        
        if len(user_recs) == 0:
            continue
        
        # Count how many recommendations are relevant
        relevant_recs = user_recs[
            user_recs['movieId'].isin(user_relevant)
        ]
        
        precision = len(relevant_recs) / min(len(user_recs), k)
        user_precisions.append(precision)
    
    avg_precision = np.mean(user_precisions) if user_precisions else 0
    print(f"   ✅ Average Precision@{k}: {avg_precision:.4f}")
    
    return avg_precision


def calculate_recall_at_k(recommendations_df: pd.DataFrame,
                        relevant_items_df: pd.DataFrame,
                        k: int = 10,
                        relevance_threshold: float = 4.0) -> float:
    """
    Calculate Recall@K - what fraction of relevant items were recommended?
    
    Args:
        recommendations_df: DataFrame with user recommendations
        relevant_items_df: DataFrame with items users actually liked
        k: Number of top recommendations to consider
        relevance_threshold: Minimum rating to consider item as relevant
        
    Returns:
        Average Recall@K across all users
    """
    print(f"🔍 Calculating Recall@{k}...")
    
    # Define relevant items
    relevant_items = relevant_items_df[
        relevant_items_df['rating'] >= relevance_threshold
    ]
    
    user_recalls = []
    
    for user_id in recommendations_df['userId'].unique():
        # Get top-k recommendations for this user
        user_recs = recommendations_df[
            recommendations_df['userId'] == user_id
        ].head(k)
        
        # Get relevant items for this user
        user_relevant = relevant_items[
            relevant_items['userId'] == user_id
        ]['movieId'].tolist()
        
        if len(user_relevant) == 0:  # No relevant items for this user
            continue
        
        # Count how many relevant items were recommended
        relevant_recs = user_recs[
            user_recs['movieId'].isin(user_relevant)
        ]
        
        recall = len(relevant_recs) / len(user_relevant)
        user_recalls.append(recall)
    
    avg_recall = np.mean(user_recalls) if user_recalls else 0
    print(f"   ✅ Average Recall@{k}: {avg_recall:.4f}")
    
    return avg_recall


def main():
    """Example usage of the evaluation metrics."""
    print("🧪 Testing evaluation metrics with sample data...")
    
    # Create sample prediction data
    sample_predictions = pd.DataFrame({
        'userId': [1, 1, 1, 2, 2, 2, 3, 3, 3],
        'movieId': [101, 102, 103, 201, 202, 203, 301, 302, 303],
        'prediction': [4.5, 3.8, 4.2, 3.9, 4.1, 3.5, 4.3, 4.0, 3.7],
        'rating': [5.0, 4.0, 4.0, 4.0, 4.0, 3.0, 5.0, 4.0, 4.0]
    })
    
    # Create sample test data
    sample_test = pd.DataFrame({
        'userId': [1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3],
        'movieId': [101, 102, 103, 104, 201, 202, 203, 204, 301, 302, 303, 304],
        'rating': [5.0, 4.0, 4.0, 3.0, 4.0, 4.0, 3.0, 5.0, 5.0, 4.0, 4.0, 3.0]
    })
    
    # Initialize evaluator
    evaluator = RecommendationEvaluator()
    
    # Run evaluation
    results = evaluator.evaluate_recommender_system(
        sample_predictions, 
        sample_test, 
        system_name="Sample System"
    )
    
    print(f"\n📊 Sample Evaluation Results:")
    for category, metrics in results.items():
        if isinstance(metrics, dict):
            print(f"\n{category.upper()}:")
            for metric, value in metrics.items():
                print(f"  {metric}: {value}")


if __name__ == "__main__":
    main()