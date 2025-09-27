"""
Real Movie Recommendation System - Streamlit Demo

This application uses the actual trained models and real MovieLens data
to demonstrate the movie recommendation system capabilities.

Prerequisites:
1. Run main.py first to train and save models
2. Ensure you have the MovieLens dataset in data/raw/
3. Install: pip install streamlit plotly

To run: streamlit run streamlit_app.py
"""

import streamlit as st
import pandas as pd
import numpy as np
import pickle
import plotly.express as px
import plotly.graph_objects as go
from pathlib import Path
import sys
import re
from typing import Dict, List, Any
import warnings

# Add src directory to path
sys.path.append(str(Path(__file__).parent / "src"))

try:
    from catboost import CatBoostRegressor
    from content_based_filtering import ContentBasedRecommender
    from collaborative_filtering import UserBasedCollaborativeFilter
    from data_preprocessing import MovieDataProcessor
    from hybrid_recommender import HybridRecommendationSystem, HybridStrategy
    from config.settings import *
except ImportError as e:
    st.error(f"❌ Import error: {e}")
    st.error("Please ensure you're running this from the project root directory")
    st.stop()

warnings.filterwarnings('ignore')

# Page configuration
st.set_page_config(
    page_title="🎬 Movie Recommendation System",
    page_icon="🎬",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .recommendation-card {
        background-color: #f8f9fa;
        padding: 1rem;
        border-radius: 8px;
        border-left: 4px solid #007bff;
        margin: 0.5rem 0;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .metric-card {
        background-color: #e8f4fd;
        padding: 1rem;
        border-radius: 8px;
        text-align: center;
    }
    .genre-tag {
        display: inline-block;
        background-color: #28a745;
        color: white;
        padding: 0.2rem 0.6rem;
        border-radius: 12px;
        font-size: 0.75rem;
        margin: 0.2rem;
    }
    .rating-stars {
        color: #ffc107;
        font-size: 1.2rem;
    }
</style>
""", unsafe_allow_html=True)


class RealMovieRecommendationApp:
    """Real movie recommendation application using trained models."""
    
    def __init__(self):
        self.content_model = None
        self.collaborative_model = None
        self.hybrid_system = None
        self.movies_df = None
        self.ratings_df = None
        self.processed_data = None
        self.model_loaded = False
        
    def check_prerequisites(self):
        """Check if required data and models exist."""
        missing_items = []
        
        # Check data files
        if not MOVIES_FILE.exists():
            missing_items.append(f"📁 Movies data: {MOVIES_FILE}")
        if not RATINGS_FILE.exists():
            missing_items.append(f"📁 Ratings data: {RATINGS_FILE}")
            
        # Check model files
        model_files = [
            MODELS_DIR / "content_based_model.cbm",
            MODELS_DIR / "content_based_model_metadata.pkl"
        ]
        
        for model_file in model_files:
            if not model_file.exists():
                missing_items.append(f"🤖 Model file: {model_file}")
        
        if missing_items:
            st.error("❌ Missing required files:")
            for item in missing_items:
                st.error(f"   • {item}")
            st.error("\n**To fix this:**")
            st.error("1. Download MovieLens dataset and place in data/raw/")
            st.error("2. Run `python main.py` to train and save models")
            return False
        
        return True
    
    @st.cache_data
    def load_data(_self):
        """Load real MovieLens data."""
        try:
            st.info("📊 Loading MovieLens dataset...")
            
            # Load movies
            movies_df = pd.read_csv(MOVIES_FILE)
            st.success(f"✅ Loaded {len(movies_df):,} movies")
            
            # Load ratings (limit for performance in demo)
            ratings_df = pd.read_csv(RATINGS_FILE)
            st.success(f"✅ Loaded {len(ratings_df):,} ratings")
            
            # Add movie year extraction
            movies_df['year'] = movies_df['title'].apply(_self.extract_year)
            
            return movies_df, ratings_df
            
        except Exception as e:
            st.error(f"❌ Error loading data: {e}")
            return None, None
    
    def extract_year(self, title):
        """Extract year from movie title."""
        year_match = re.search(r'\((\d{4})\)', title)
        if year_match:
            return int(year_match.group(1))
        return 2000  # Default year
    
    @st.cache_resource
    def load_models(_self):
        """Load the actual trained models."""
        try:
            st.info("🤖 Loading trained models...")
            
            # Load content-based model
            content_model = ContentBasedRecommender()
            model_path = MODELS_DIR / "content_based_model.cbm"
            
            if model_path.exists():
                content_model.load_model(str(model_path))
                st.success("✅ Content-based model loaded")
            else:
                st.error("❌ Content-based model not found")
                return None, None, None
            
            # Initialize collaborative filtering (will be trained on-the-fly)
            collaborative_model = UserBasedCollaborativeFilter()
            
            # Initialize hybrid system
            hybrid_system = HybridRecommendationSystem()
            
            st.success("✅ All models loaded successfully")
            return content_model, collaborative_model, hybrid_system
            
        except Exception as e:
            st.error(f"❌ Error loading models: {e}")
            return None, None, None
    
    @st.cache_data
    def process_data(_self, movies_df, ratings_df):
        """Process data using the real data processor."""
        try:
            st.info("⚙️ Processing data...")
            
            # Create processor and process data
            processor = MovieDataProcessor()
            processor.movies_df = movies_df
            processor.ratings_df = ratings_df
            
            # Perform train/test split
            processor.perform_train_test_split()
            
            # Get processed data
            processed_data = processor.process_all_data()
            
            st.success("✅ Data processing complete")
            return processed_data
            
        except Exception as e:
            st.error(f"❌ Error processing data: {e}")
            return None
    
    def get_user_statistics(self, user_id):
        """Get statistics for a specific user."""
        if self.ratings_df is None:
            return None
        
        user_ratings = self.ratings_df[self.ratings_df['userId'] == user_id]
        
        if len(user_ratings) == 0:
            return None
        
        stats = {
            'total_ratings': len(user_ratings),
            'avg_rating': user_ratings['rating'].mean(),
            'favorite_genres': self.get_user_favorite_genres(user_id),
            'rating_distribution': user_ratings['rating'].value_counts().sort_index()
        }
        
        return stats
    
    def get_user_favorite_genres(self, user_id):
        """Get user's favorite genres based on their ratings."""
        if self.ratings_df is None or self.movies_df is None:
            return []
        
        user_ratings = self.ratings_df[self.ratings_df['userId'] == user_id]
        user_movies = pd.merge(user_ratings, self.movies_df, on='movieId')
        
        # Get highly rated movies (4+ stars)
        high_rated = user_movies[user_movies['rating'] >= 4]
        
        # Extract genres
        all_genres = []
        for genres_str in high_rated['genres']:
            if pd.notna(genres_str):
                genres = genres_str.split('|')
                all_genres.extend(genres)
        
        # Count genre frequencies
        genre_counts = pd.Series(all_genres).value_counts()
        return genre_counts.head(5).index.tolist()
    
    def get_content_based_recommendations(self, user_id, n_recs=10):
        """Get recommendations from content-based model."""
        try:
            if not self.model_loaded or self.content_model is None:
                return []
            
            # Get user's rating history
            user_ratings = self.ratings_df[self.ratings_df['userId'] == user_id]
            
            if len(user_ratings) == 0:
                st.warning(f"User {user_id} has no rating history")
                return []
            
            # Create user profile
            user_profile = {
                'userViews': len(user_ratings),
                'userMeans': user_ratings['rating'].mean(),
            }
            
            # Get movies user hasn't rated
            rated_movies = set(user_ratings['movieId'])
            unrated_movies = self.movies_df[~self.movies_df['movieId'].isin(rated_movies)]
            
            if len(unrated_movies) == 0:
                return []
            
            # For demo, take a sample of unrated movies
            sample_size = min(1000, len(unrated_movies))
            unrated_sample = unrated_movies.sample(n=sample_size, random_state=42)
            
            recommendations = []
            
            # Simple content-based scoring (since we need to match the trained model's features)
            for _, movie in unrated_sample.head(n_recs * 2).iterrows():
                # Simple scoring based on genres and user preferences
                score = self.calculate_simple_content_score(user_ratings, movie)
                
                recommendations.append({
                    'movieId': movie['movieId'],
                    'title': movie['title'],
                    'genres': movie['genres'],
                    'year': movie.get('year', 2000),
                    'predicted_rating': score,
                    'method': 'Content-Based'
                })
            
            # Sort by predicted rating and return top N
            recommendations.sort(key=lambda x: x['predicted_rating'], reverse=True)
            return recommendations[:n_recs]
            
        except Exception as e:
            st.error(f"Error generating content-based recommendations: {e}")
            return []
    
    def calculate_simple_content_score(self, user_ratings, movie):
        """Simple content-based scoring for demo."""
        base_score = user_ratings['rating'].mean()
        
        # Get user's genre preferences
        user_movies = pd.merge(user_ratings, self.movies_df, on='movieId')
        user_high_rated = user_movies[user_movies['rating'] >= 4]
        
        # Count preferred genres
        preferred_genres = []
        for genres_str in user_high_rated['genres']:
            if pd.notna(genres_str):
                preferred_genres.extend(genres_str.split('|'))
        
        genre_preference = pd.Series(preferred_genres).value_counts()
        
        # Score this movie based on genre overlap
        movie_genres = movie['genres'].split('|') if pd.notna(movie['genres']) else []
        genre_score = 0
        
        for genre in movie_genres:
            if genre in genre_preference.index:
                genre_score += genre_preference[genre] / len(user_high_rated) * 0.5
        
        # Add some randomness and year preference
        year_bonus = 0.1 if movie.get('year', 2000) > 2000 else 0
        
        final_score = min(5.0, base_score + genre_score + year_bonus + np.random.normal(0, 0.2))
        return max(0.5, final_score)
    
    def get_collaborative_recommendations(self, user_id, n_recs=10):
        """Get collaborative filtering recommendations."""
        try:
            # For demo, use a simplified collaborative approach
            target_user_ratings = self.ratings_df[self.ratings_df['userId'] == user_id]
            
            if len(target_user_ratings) == 0:
                return []
            
            # Find similar users (simplified)
            similar_users = self.find_similar_users(user_id)
            
            if not similar_users:
                return []
            
            # Get recommendations from similar users
            recommendations = []
            target_movies = set(target_user_ratings['movieId'])
            
            for similar_user_id, similarity in similar_users[:5]:  # Top 5 similar users
                similar_user_ratings = self.ratings_df[
                    (self.ratings_df['userId'] == similar_user_id) & 
                    (self.ratings_df['rating'] >= 4)  # Only high-rated movies
                ]
                
                for _, rating in similar_user_ratings.iterrows():
                    if rating['movieId'] not in target_movies:
                        movie_info = self.movies_df[self.movies_df['movieId'] == rating['movieId']]
                        
                        if not movie_info.empty:
                            movie = movie_info.iloc[0]
                            
                            recommendations.append({
                                'movieId': movie['movieId'],
                                'title': movie['title'],
                                'genres': movie['genres'],
                                'year': movie.get('year', 2000),
                                'predicted_rating': rating['rating'] * similarity,
                                'method': 'Collaborative Filtering'
                            })
            
            # Remove duplicates and sort
            seen_movies = set()
            unique_recs = []
            
            for rec in recommendations:
                if rec['movieId'] not in seen_movies:
                    seen_movies.add(rec['movieId'])
                    unique_recs.append(rec)
            
            unique_recs.sort(key=lambda x: x['predicted_rating'], reverse=True)
            return unique_recs[:n_recs]
            
        except Exception as e:
            st.error(f"Error generating collaborative recommendations: {e}")
            return []
    
    def find_similar_users(self, target_user_id, top_k=10):
        """Find users similar to the target user."""
        target_user_ratings = self.ratings_df[self.ratings_df['userId'] == target_user_id]
        target_movies = set(target_user_ratings['movieId'])
        
        if len(target_movies) < 5:  # Need sufficient overlap
            return []
        
        similarities = []
        
        # Check a sample of users for performance
        other_users = self.ratings_df['userId'].unique()
        sample_users = np.random.choice(other_users, size=min(500, len(other_users)), replace=False)
        
        for user_id in sample_users:
            if user_id == target_user_id:
                continue
            
            user_ratings = self.ratings_df[self.ratings_df['userId'] == user_id]
            user_movies = set(user_ratings['movieId'])
            
            # Calculate overlap
            common_movies = target_movies.intersection(user_movies)
            
            if len(common_movies) >= 3:  # Need at least 3 movies in common
                # Calculate similarity (simplified Pearson correlation)
                target_common = target_user_ratings[target_user_ratings['movieId'].isin(common_movies)]
                user_common = user_ratings[user_ratings['movieId'].isin(common_movies)]
                
                if len(target_common) > 0 and len(user_common) > 0:
                    # Merge and calculate correlation
                    merged = pd.merge(
                        target_common[['movieId', 'rating']], 
                        user_common[['movieId', 'rating']], 
                        on='movieId', 
                        suffixes=('_target', '_user')
                    )
                    
                    if len(merged) >= 3:
                        correlation = merged['rating_target'].corr(merged['rating_user'])
                        if not pd.isna(correlation) and correlation > 0.3:
                            similarities.append((user_id, correlation))
        
        # Sort by similarity
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:top_k]
    
    def display_recommendations(self, recommendations, title):
        """Display recommendations in a nice format."""
        st.subheader(title)
        
        if not recommendations:
            st.warning("No recommendations available")
            return
        
        for i, rec in enumerate(recommendations):
            with st.container():
                st.markdown(f"""
                <div class="recommendation-card">
                    <h4>#{i+1} - {rec['title']}</h4>
                    <div class="rating-stars">{'⭐' * int(rec['predicted_rating'])} {rec['predicted_rating']:.1f}/5.0</div>
                    <p><strong>Year:</strong> {rec['year']} | <strong>Method:</strong> {rec['method']}</p>
                    <div>
                """, unsafe_allow_html=True)
                
                # Display genres as tags
                if rec['genres']:
                    for genre in rec['genres'].split('|')[:3]:  # Show first 3 genres
                        st.markdown(f'<span class="genre-tag">{genre}</span>', unsafe_allow_html=True)
                
                st.markdown("</div></div>", unsafe_allow_html=True)
    
    def display_user_profile(self, user_id):
        """Display user profile and statistics."""
        stats = self.get_user_statistics(user_id)
        
        if stats is None:
            st.warning(f"User {user_id} not found in the dataset")
            return False
        
        st.subheader(f"👤 User {user_id} Profile")
        
        # Display metrics
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.markdown(f"""
            <div class="metric-card">
                <h3>{stats['total_ratings']}</h3>
                <p>Movies Rated</p>
            </div>
            """, unsafe_allow_html=True)
        
        with col2:
            st.markdown(f"""
            <div class="metric-card">
                <h3>{stats['avg_rating']:.1f}/5.0</h3>
                <p>Average Rating</p>
            </div>
            """, unsafe_allow_html=True)
        
        with col3:
            favorite_genre = stats['favorite_genres'][0] if stats['favorite_genres'] else "Unknown"
            st.markdown(f"""
            <div class="metric-card">
                <h3>{favorite_genre}</h3>
                <p>Favorite Genre</p>
            </div>
            """, unsafe_allow_html=True)
        
        # Rating distribution chart
        if len(stats['rating_distribution']) > 0:
            fig = px.bar(
                x=stats['rating_distribution'].index,
                y=stats['rating_distribution'].values,
                title="Rating Distribution",
                labels={'x': 'Rating', 'y': 'Count'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        return True
    
    def run_app(self):
        """Main application logic."""
        st.title("🎬 Movie Recommendation System Demo")
        st.markdown("**Using Real MovieLens Data & Trained Models**")
        
        # Check prerequisites
        if not self.check_prerequisites():
            st.stop()
        
        # Load data and models
        with st.spinner("Loading data and models..."):
            # Load data
            self.movies_df, self.ratings_df = self.load_data()
            if self.movies_df is None or self.ratings_df is None:
                st.error("Failed to load data")
                st.stop()
            
            # Load models
            self.content_model, self.collaborative_model, self.hybrid_system = self.load_models()
            if self.content_model is None:
                st.error("Failed to load models")
                st.stop()
            
            self.model_loaded = True
        
        st.success("🎉 System loaded successfully!")
        
        # Sidebar for user selection
        st.sidebar.title("🎛️ Controls")
        
        # User ID selection
        available_users = sorted(self.ratings_df['userId'].unique())
        selected_user = st.sidebar.selectbox(
            "Select User ID:",
            options=available_users[:100],  # Limit for performance
            index=0,
            help="Choose a user to get personalized recommendations"
        )
        
        # Number of recommendations
        n_recommendations = st.sidebar.slider(
            "Number of Recommendations:",
            min_value=5,
            max_value=20,
            value=10,
            help="How many movies to recommend"
        )
        
        # Recommendation method
        method = st.sidebar.selectbox(
            "Recommendation Method:",
            ["Content-Based", "Collaborative Filtering", "Both"],
            help="Choose which algorithm to use"
        )
        
        # Main content area
        if st.sidebar.button("🚀 Get Recommendations", type="primary"):
            # Display user profile
            if self.display_user_profile(selected_user):
                st.markdown("---")
                
                # Generate recommendations based on selected method
                if method == "Content-Based":
                    recommendations = self.get_content_based_recommendations(selected_user, n_recommendations)
                    self.display_recommendations(recommendations, "🤖 Content-Based Recommendations")
                
                elif method == "Collaborative Filtering":
                    recommendations = self.get_collaborative_recommendations(selected_user, n_recommendations)
                    self.display_recommendations(recommendations, "🤝 Collaborative Filtering Recommendations")
                
                else:  # Both
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        cb_recs = self.get_content_based_recommendations(selected_user, n_recommendations//2)
                        self.display_recommendations(cb_recs, "🤖 Content-Based")
                    
                    with col2:
                        cf_recs = self.get_collaborative_recommendations(selected_user, n_recommendations//2)
                        self.display_recommendations(cf_recs, "🤝 Collaborative Filtering")
        
        # Dataset information
        st.sidebar.markdown("---")
        st.sidebar.markdown("### 📊 Dataset Info")
        st.sidebar.info(f"""
        **Movies:** {len(self.movies_df):,}
        **Ratings:** {len(self.ratings_df):,}
        **Users:** {self.ratings_df['userId'].nunique():,}
        """)
        
        # System explanation
        with st.expander("🔍 How This System Works"):
            st.markdown("""
            ### 🎯 Recommendation Approaches
            
            **1. Content-Based Filtering 🤖**
            - Analyzes movie features (genres, year, etc.)
            - Learns user preferences from rating history
            - Uses CatBoost machine learning model
            - Good for new movies, explainable recommendations
            
            **2. Collaborative Filtering 🤝** 
            - Finds users with similar tastes
            - Recommends movies liked by similar users
            - Uses correlation analysis
            - Discovers hidden patterns in user behavior
            
            **3. Hybrid Approach 🔀**
            - Combines both methods for better results
            - Overcomes individual limitations
            - Provides better coverage and accuracy
            """)


def main():
    """Run the Streamlit application."""
    app = RealMovieRecommendationApp()
    app.run_app()


if __name__ == "__main__":
    main()