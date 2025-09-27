# 🎬 Movie Recommendation System

A comprehensive movie recommendation system implementing multiple approaches: collaborative filtering, content-based filtering, and hybrid methods. This system demonstrates modern recommendation techniques using the MovieLens dataset.

[![Python](https://img.shields.io/badge/Python-3.8%2B-blue)](https://python.org)
[![CatBoost](https://img.shields.io/badge/CatBoost-Latest-green)](https://catboost.ai)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🌟 Features

- **Multiple Recommendation Approaches**
  - 🤝 **Collaborative Filtering**: User-based recommendations using correlation analysis
  - 🤖 **Content-Based Filtering**: Feature-based recommendations using CatBoost ML
  - 🔀 **Hybrid Systems**: Intelligent combination of multiple approaches

- **Comprehensive Evaluation**
  - 📊 DSG@K (Discounted Cumulative Gain) for ranking quality
  - 📈 RMSE, MAE, R² for rating prediction accuracy
  - 🎯 Coverage analysis for recommendation reach
  - 🌈 Diversity metrics to avoid filter bubbles

- **Production-Ready Features**
  - ❄️ Cold start handling for new users and items
  - 💾 Model serialization and deployment support
  - 📋 Comprehensive logging and error handling
  - 🔧 Configurable parameters and strategies

## 🚀 Quick Start

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/SahinBabazada/movie-recommendation-system.git
   cd movie-recommendation-system
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Download MovieLens dataset**
   - Download from [GroupLens](https://grouplens.org/datasets/movielens/)
   - Place `movies.csv` and `ratings.csv` in `data/raw/`

4. **Run the complete pipeline**
   ```bash
   python main.py
   ```

### Basic Usage

```python
from src import MovieDataProcessor, HybridRecommendationSystem

# Load and preprocess data
processor = MovieDataProcessor()
data = processor.process_all_data()

# Train hybrid recommendation system
recommender = HybridRecommendationSystem()
recommender.fit({
    'collaborative': data['collaborative'],
    'content_based': data['content_based']
})

# Get recommendations for a user
recommendations = recommender.get_recommendations(
    user_id=123, 
    n_recommendations=10
)

print("🎬 Recommended movies:")
for i, rec in enumerate(recommendations, 1):
    print(f"{i}. Movie {rec['movieId']}: {rec['prediction']:.2f} ⭐")
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
│
├── 📂 notebooks/
│   └── 📄 recommendation_analysis.ipynb  # Interactive analysis
│
├── 📄 main.py                     # Main pipeline script
├── 📄 requirements.txt            # Dependencies
└── 📄 README.md                   # This file
```

## 🔧 Configuration

Customize the system behavior in `config/settings.py`:

```python
# Data processing
TEST_SIZE = 20000                  # Test set size
USER_NOISE_STD = 0.1              # Noise for user features

# Model parameters
CATBOOST_PARAMS = {
    'iterations': 1000,
    'learning_rate': 0.1,
    'depth': 6,
    'random_seed': 42
}

# Evaluation
DSG_K = 2                         # Top-K for DSG calculation
MIN_CORRELATION = 0.0             # Min correlation for CF
```

## 📊 Algorithms Explained

### 🤝 Collaborative Filtering

Finds users with similar rating patterns and uses their preferences to predict ratings:

```
prediction(user, item) = user_mean + 
    Σ(neighbor_rating - neighbor_mean) × correlation / Σ(correlations)
```

**Strengths**: Captures hidden patterns, no content analysis needed  
**Weaknesses**: Cold start problem, sparsity issues

### 🤖 Content-Based Filtering

Uses machine learning to predict ratings based on item features and user behavior:

**Features**:
- Movie genres (one-hot encoded)
- Release year
- User viewing history
- User rating patterns

**Algorithm**: CatBoost Gradient Boosting

**Strengths**: Handles cold start, explainable recommendations  
**Weaknesses**: Limited by feature quality, potential filter bubbles

### 🔀 Hybrid Systems

Combines multiple approaches using different strategies:

- **Weighted**: Linear combination of predictions
- **Switching**: Choose method based on confidence
- **Mixed**: Alternate recommendations from different systems
- **Cascade**: Use one system to refine another's output

## 📈 Evaluation Metrics

### DSG@K (Discounted Cumulative Gain)
Measures ranking quality by considering both relevance and position:
```
DSG@K = Σ(relevance_i / log₂(position_i + 1)) for i in top_k_items
```

### Rating Accuracy
- **RMSE**: Root Mean Squared Error
- **MAE**: Mean Absolute Error  
- **R²**: Coefficient of determination

### System Coverage
- **User Coverage**: % of users who can receive recommendations
- **Item Coverage**: % of items that can be recommended
- **Overall Coverage**: % of user-item pairs predictable

## 🧪 Running Experiments

### Compare Different Strategies
```python
from src.hybrid_recommender import compare_hybrid_strategies

# Compare all hybrid combination strategies
comparison = compare_hybrid_strategies(train_data, test_data)
print(comparison)
```

### Optimize Hybrid Weights
```python
from src.hybrid_recommender import optimize_hybrid_weights

# Find optimal weights for combining systems
best_weights = optimize_hybrid_weights(
    train_data, 
    validation_data,
    weight_range=(0.1, 0.9),
    step_size=0.1
)
```

### Interactive Analysis
Launch the Jupyter notebook for detailed analysis:
```bash
jupyter notebook notebooks/recommendation_analysis.ipynb
```

## 🎯 Results Example

```
🏆 FINAL COMPARISON:
System                    DSG@K    RMSE     MAE      R²       Coverage
Collaborative Filtering   2.3456   0.9123   0.7234   0.6789   45.2%
Content-Based Filtering   2.1234   0.8765   0.6891   0.7123   98.7%
Hybrid System            2.5678   0.8456   0.6543   0.7456   87.3%

🥇 Best performing system: Hybrid System
```

## 🚀 Production Deployment

### Model Serving
```python
# Save trained model
recommender.save_models()

# Load for inference
def get_recommendations_api(user_id: int, n_recs: int = 10):
    """API endpoint for getting recommendations"""
    # Load saved model
    model = load_hybrid_model("models/hybrid_model.pkl")
    
    # Generate recommendations
    recommendations = model.get_recommendations(user_id, n_recs)
    
    return {
        "user_id": user_id,
        "recommendations": recommendations,
        "timestamp": datetime.now().isoformat()
    }
```

### Batch Processing
```python
# Generate recommendations for all users
def batch_generate_recommendations():
    """Generate recommendations for all users in batch"""
    all_recommendations = {}
    
    for user_id in user_list:
        recs = recommender.get_recommendations(user_id, 50)
        all_recommendations[user_id] = recs
    
    # Save to database or file
    save_recommendations(all_recommendations)
```

## 🔍 Troubleshooting

### Common Issues

**Q: "No predictions generated"**  
A: Check data format and ensure train/test split is correct. Verify file paths in config.

**Q: "Poor collaborative filtering performance"**  
A: Data might be too sparse. Try lowering `MIN_CORRELATION` or increasing minimum neighbors.

**Q: "CatBoost training fails"**  
A: Check feature types and ensure categorical features are properly specified.

**Q: "Memory issues with large datasets"**  
A: Implement batch processing or reduce dataset size for testing.

### Performance Tips

1. **For large datasets**: Use sampling for development, full data for production
2. **Speed up training**: Reduce CatBoost iterations or use GPU acceleration
3. **Improve accuracy**: Tune hyperparameters, add more features
4. **Handle sparsity**: Collect implicit feedback (views, clicks, time spent)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md).

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📚 References

- [MovieLens Dataset](https://grouplens.org/datasets/movielens/)
- [Collaborative Filtering Techniques](https://dl.acm.org/doi/10.1145/371920.372071)
- [Content-Based Recommendation Systems](https://link.springer.com/chapter/10.1007/978-0-387-85820-3_3)
- [Hybrid Recommendation Systems](https://link.springer.com/article/10.1023/A:1021240730564)
- [CatBoost Documentation](https://catboost.ai/docs/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- GroupLens Research for the MovieLens dataset
- Yandex for the CatBoost library
- The open-source community for inspiration and tools

---

**Built with ❤️ for better movie recommendations**

*Have questions? Open an issue or reach out to the team!*