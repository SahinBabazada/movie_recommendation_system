# 🎬 Movie Recommendation System

A comprehensive movie recommendation system implementing multiple approaches: collaborative filtering, content-based filtering, and hybrid methods. This system demonstrates modern recommendation techniques using the MovieLens dataset with **real-time inference capabilities** and an **interactive Streamlit demo**.

[![Python](https://img.shields.io/badge/Python-3.8%2B-blue)](https://python.org)
[![CatBoost](https://img.shields.io/badge/CatBoost-Latest-green)](https://catboost.ai)
[![Streamlit](https://img.shields.io/badge/Streamlit-Demo-red)](https://streamlit.io)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🌟 Features

- **Multiple Recommendation Approaches**
  - 🤝 **Collaborative Filtering**: User-based recommendations using correlation analysis
  - 🤖 **Content-Based Filtering**: Feature-based recommendations using CatBoost ML
  - 🔀 **Hybrid Systems**: Intelligent combination of multiple approaches

- **Interactive Demo Application** 🎪
  - 📱 **Streamlit Web App**: Real-time recommendation demo
  - 👤 **User Profile Analysis**: Explore real user preferences and patterns
  - 🎯 **Live Recommendations**: Generate personalized movie suggestions
  - 📊 **Algorithm Comparison**: Side-by-side view of different approaches

- **Production-Ready Features**
  - ❄️ Cold start handling for new users and items
  - 💾 Model serialization (.cbm, .pkl files) for deployment
  - 📋 Comprehensive logging and error handling
  - 🔧 Configurable parameters and strategies

- **Comprehensive Evaluation**
  - 📊 DSG@K (Discounted Cumulative Gain) for ranking quality
  - 📈 RMSE, MAE, R² for rating prediction accuracy
  - 🎯 Coverage analysis for recommendation reach
  - 🌈 Diversity metrics to avoid filter bubbles

## 🚀 Quick Start

### Prerequisites

1. **Python 3.8+**
2. **MovieLens Dataset** (automatically downloaded or manual)
3. **Required packages** (see requirements.txt)

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/SahinBabazada/movie-recommendation-system.git
   cd movie-recommendation-system
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   pip install streamlit plotly  # For demo app
   ```

3. **Download MovieLens dataset**
   
   **Option A: Automatic (recommended)**
   ```bash
   python setup_demo.py  # Downloads data and sets up everything
   ```
   
   **Option B: Manual**
   - Download from [GroupLens](https://grouplens.org/datasets/movielens/)
   - Extract `movies.csv` and `ratings.csv` to `data/raw/`

4. **Train the models**
   ```bash
   python main.py
   ```
   This creates trained models in `models/saved_models/`:
   - `content_based_model.cbm` (CatBoost model)
   - `content_based_model_metadata.pkl` (model metadata)

5. **Launch the interactive demo** 🎪
   ```bash
   streamlit run streamlit_app.py
   ```

## 🎪 Interactive Demo

The Streamlit demo provides a **user-friendly interface** to explore the recommendation system:

### 🎯 Demo Features

- **👤 Real User Profiles**: Select from actual MovieLens users (600+ users)
- **📊 User Analytics**: View rating history, favorite genres, and preferences
- **🎬 Live Recommendations**: Get personalized movie suggestions in real-time
- **🔄 Algorithm Comparison**: Compare Content-Based vs Collaborative Filtering
- **📈 Interactive Charts**: Visualize user behavior and recommendation quality
- **🔍 Explainable AI**: Understand why specific movies were recommended

### 🎬 Demo Screenshots & Flow

1. **User Selection**: Choose a real user from the dataset
2. **Profile Analysis**: Explore user's movie preferences and rating patterns
3. **Recommendation Generation**: Get personalized suggestions with confidence scores
4. **Method Comparison**: See how different algorithms perform

### 📱 Demo Usage

```bash
# Start the demo
streamlit run streamlit_app.py

# Navigate to http://localhost:8501
# Select a user ID (1-610)
# Choose recommendation method
# Click "Get Recommendations"
```

## 📁 Project Structure

```
movie_recommendation_system/
│
├── 📂 data/
│   ├── 📂 raw/                    # Original datasets
│   │   ├── movies.csv
│   │   └── ratings.csv
│   └── 📂 processed/              # Preprocessed data
│
├── 📂 src/                        # Source code
│   ├── 📄 __init__.py
│   ├── 📄 data_preprocessing.py   # Data loading and feature engineering
│   ├── 📄 collaborative_filtering.py  # User-based collaborative filtering
│   ├── 📄 content_based_filtering.py  # Content-based recommendations
│   ├── 📄 hybrid_recommender.py   # Hybrid system implementation
│   └── 📄 evaluation_metrics.py   # Evaluation and comparison tools
│
├── 📂 config/
│   └── 📄 settings.py             # Configuration parameters
│
├── 📂 models/
│   └── 📂 saved_models/           # Trained model storage
│       ├── content_based_model.cbm     # CatBoost model
│       └── content_based_model_metadata.pkl  # Model metadata
│
├── 📂 notebooks/
│   └── 📄 recommendation_analysis.ipynb  # Interactive analysis
│
├── 📄 main.py                     # Main pipeline script
├── 📄 streamlit_app.py           # Interactive demo application
├── 📄 setup_demo.py              # Automated setup script
├── 📄 requirements.txt            # Core dependencies
└── 📄 README.md                   # This file
```

## 🤖 Algorithm Implementations

### 🤝 Collaborative Filtering

**Approach**: "Users like you also enjoyed..."

```python
# Find similar users based on rating patterns
user_correlations = calculate_user_similarity(ratings_matrix)

# Predict ratings using weighted neighbor ratings
prediction = user_mean + Σ(neighbor_deviation × correlation) / Σ(correlations)
```

**Strengths**: 
- Discovers hidden patterns and serendipitous recommendations
- No need for content analysis
- Captures user behavior nuances

**Weaknesses**: 
- Cold start problem for new users/items
- Sparsity issues with limited data

### 🤖 Content-Based Filtering

**Approach**: "Since you liked X, you might like Y because they're similar"

```python
# Extract movie features and user preferences
features = [movie_genres, release_year, user_history, user_preferences]

# Train CatBoost model to predict ratings
model = CatBoostRegressor(iterations=1000, learning_rate=0.1)
model.fit(X_train, y_train)

# Predict ratings for new movies
predictions = model.predict(user_movie_features)
```

**Strengths**:
- Handles new items well (no cold start for movies)
- Explainable recommendations
- Stable and consistent performance

**Weaknesses**:
- Limited by feature quality
- May create filter bubbles
- Requires domain knowledge for features

### 🔀 Hybrid Systems

**Approach**: "Best of both worlds"

Available strategies:
- **Weighted**: `hybrid_score = α × collaborative_score + β × content_score`
- **Switching**: Use collaborative when confident, else content-based
- **Mixed**: Alternate recommendations from both systems
- **Cascade**: Use one system to refine the other's output

## 📊 Performance Metrics

The system provides comprehensive evaluation using multiple metrics:

### 🎯 Ranking Quality
- **DSG@K**: Discounted Cumulative Gain at K positions
- **Precision@K**: Fraction of top-K recommendations that are relevant
- **Recall@K**: Fraction of relevant items found in top-K recommendations

### 📈 Rating Accuracy
- **RMSE**: Root Mean Squared Error for rating predictions
- **MAE**: Mean Absolute Error for rating predictions  
- **R²**: Coefficient of determination for model fit

### 🎪 System Coverage
- **User Coverage**: Percentage of users who can receive recommendations
- **Item Coverage**: Percentage of items that can be recommended
- **Overall Coverage**: Percentage of user-item pairs predictable

### 🌈 Diversity Analysis
- **Shannon Diversity**: Genre diversity in recommendations
- **Intra-list Diversity**: Variety within a user's recommendation list

## 🔧 Configuration

Customize system behavior in `config/settings.py`:

```python
# Data processing
TEST_SIZE = 20000                  # Test set size for evaluation
USER_NOISE_STD = 0.1              # Noise factor for user features

# Model parameters
CATBOOST_PARAMS = {
    'iterations': 1000,
    'learning_rate': 0.1,
    'depth': 6,
    'random_seed': 42
}

# Evaluation settings
DSG_K = 2                         # Top-K for DSG calculation
MIN_CORRELATION = 0.0             # Min correlation for collaborative filtering
```

## 🚀 Production Deployment

### Model Serving Example

```python
# Load trained models
content_model = ContentBasedRecommender()
content_model.load_model("models/saved_models/content_based_model.cbm")

# API endpoint for recommendations
@app.route('/recommend/<int:user_id>')
def get_recommendations(user_id):
    # Load user profile
    user_profile = build_user_profile(user_id)
    
    # Generate recommendations
    recommendations = content_model.get_movie_recommendations(
        user_profile, movie_catalog, n_recommendations=10
    )
    
    return jsonify({
        "user_id": user_id,
        "recommendations": recommendations,
        "timestamp": datetime.now().isoformat()
    })
```

### Batch Processing

```python
# Generate recommendations for all users
def batch_generate_recommendations():
    """Generate recommendations for all users in batch mode."""
    for user_id in active_users:
        recommendations = hybrid_system.get_recommendations(user_id, 50)
        save_to_database(user_id, recommendations)
```

## 🔬 Advanced Analysis

### Compare Hybrid Strategies

```python
from src.hybrid_recommender import compare_hybrid_strategies

# Compare all combination strategies
comparison_results = compare_hybrid_strategies(train_data, test_data)
print(comparison_results)
```

### Optimize Weights

```python
from src.hybrid_recommender import optimize_hybrid_weights

# Find optimal combination weights
best_weights = optimize_hybrid_weights(
    train_data, validation_data,
    weight_range=(0.1, 0.9), step_size=0.1
)
```

## 📊 Example Results

```
🏆 FINAL COMPARISON:
System                    DSG@K    RMSE     MAE      R²       Coverage
Collaborative Filtering   2.3456   0.9123   0.7234   0.6789   45.2%
Content-Based Filtering   2.1234   0.8765   0.6891   0.7123   98.7%
Hybrid System            2.5678   0.8456   0.6543   0.7456   87.3%

🥇 Best performing system: Hybrid System
```

## 🎯 Use Cases & Applications

### 🎬 Entertainment Platforms
- **Streaming Services**: Netflix, Amazon Prime, Disney+
- **Music Platforms**: Spotify, Apple Music
- **Video Games**: Steam, PlayStation Store

### 🛍️ E-Commerce
- **Product Recommendations**: Amazon, eBay
- **Fashion**: ASOS, Zara online stores
- **Books**: Goodreads, Amazon Books

### 📰 Content Platforms
- **News**: Google News, Apple News
- **Social Media**: Facebook, Twitter feeds
- **Learning**: Coursera, Udemy course suggestions

## 🔍 Troubleshooting

### Common Issues

**Q: "No predictions generated"**  
A: Check data format and ensure train/test split is correct. Verify file paths in config.

**Q: "ModuleNotFoundError in Streamlit app"**  
A: Ensure you're running from the project root directory and all dependencies are installed.

**Q: "CatBoost training fails"**  
A: Check feature types and ensure categorical features are properly specified.

**Q: "Streamlit app shows no users"**  
A: Verify MovieLens data is in `data/raw/` and models are trained (run `main.py` first).

**Q: "Poor recommendation quality"**  
A: Try tuning hyperparameters or collecting more user interaction data.

### Performance Tips

1. **For large datasets**: Use sampling for development, full data for production
2. **Speed up training**: Reduce CatBoost iterations or use GPU acceleration
3. **Improve accuracy**: Tune hyperparameters, add more features, collect implicit feedback
4. **Handle sparsity**: Use matrix factorization techniques for very sparse data

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes** (code, tests, documentation)
4. **Run tests** (`python -m pytest tests/`)
5. **Commit changes** (`git commit -m 'Add amazing feature'`)
6. **Push to branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

### Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/movie-recommendation-system.git

# Install development dependencies
pip install -r requirements.txt
pip install pytest black flake8  # Development tools

# Run tests
python -m pytest tests/

# Format code
black src/
```

## 📚 References & Resources

### Academic Papers
- [Collaborative Filtering Techniques](https://dl.acm.org/doi/10.1145/371920.372071)
- [Content-Based Recommendation Systems](https://link.springer.com/chapter/10.1007/978-0-387-85820-3_3)
- [Hybrid Recommendation Systems](https://link.springer.com/article/10.1023/A:1021240730564)

### Datasets & Tools
- [MovieLens Dataset](https://grouplens.org/datasets/movielens/)
- [CatBoost Documentation](https://catboost.ai/docs/)
- [Streamlit Documentation](https://docs.streamlit.io/)

### Learning Resources
- [Recommender Systems Handbook](https://link.springer.com/book/10.1007/978-1-4899-7637-6)
- [Building Recommender Systems with Python](https://www.packtpub.com/product/hands-on-recommendation-systems-with-python/9781788993753)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **GroupLens Research** for the MovieLens dataset
- **Yandex** for the CatBoost library
- **Streamlit** for the amazing demo framework
- **The open-source community** for inspiration and tools

## 📞 Support & Contact

- **Issues**: [GitHub Issues](https://github.com/SahinBabazada/movie-recommendation-system/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SahinBabazada/movie-recommendation-system/discussions)
- **Email**: [contact@movierecsys.com](mailto:contact@movierecsys.com)

---

**🎬 Built with ❤️ for better movie recommendations**

*Ready to revolutionize how people discover movies? Start with our interactive demo!*

```bash
# Get started in 3 steps:
python setup_demo.py        # 1. Setup everything automatically
python main.py               # 2. Train the models  
streamlit run streamlit_app.py  # 3. Launch the demo
```