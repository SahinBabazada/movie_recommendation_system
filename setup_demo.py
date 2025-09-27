"""
Setup script for Movie Recommendation System Demo

This script helps you prepare everything needed for the Streamlit demo:
1. Check if MovieLens data exists
2. Train models if they don't exist
3. Install required packages
4. Launch the Streamlit app

Usage: python setup_demo.py
"""

import os
import sys
import subprocess
from pathlib import Path
import urllib.request
import zipfile
import shutil

def check_and_install_packages():
    """Check and install required packages."""
    required_packages = [
        'streamlit',
        'plotly',
        'pandas',
        'numpy',
        'catboost',
        'scikit-learn',
        'tqdm'
    ]
    
    print("📦 Checking required packages...")
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
            print(f"   ✅ {package}")
        except ImportError:
            missing_packages.append(package)
            print(f"   ❌ {package}")
    
    if missing_packages:
        print(f"\n🔧 Installing missing packages: {', '.join(missing_packages)}")
        subprocess.check_call([
            sys.executable, "-m", "pip", "install"
        ] + missing_packages)
        print("✅ All packages installed!")
    else:
        print("✅ All required packages are already installed!")

def download_movielens_data():
    """Download MovieLens dataset if it doesn't exist."""
    data_dir = Path("data/raw")
    movies_file = data_dir / "movies.csv"
    ratings_file = data_dir / "ratings.csv"
    
    if movies_file.exists() and ratings_file.exists():
        print("✅ MovieLens data already exists!")
        return True
    
    print("📥 MovieLens data not found. Downloading...")
    
    # Create directories
    data_dir.mkdir(parents=True, exist_ok=True)
    
    # Download MovieLens 25M dataset (smaller version)
    url = "https://files.grouplens.org/datasets/movielens/ml-latest-small.zip"
    zip_path = data_dir / "movielens.zip"
    
    try:
        print(f"   Downloading from {url}...")
        urllib.request.urlretrieve(url, zip_path)
        
        print("   Extracting files...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(data_dir)
        
        # Move files to correct location
        extracted_dir = data_dir / "ml-latest-small"
        if extracted_dir.exists():
            shutil.move(str(extracted_dir / "movies.csv"), str(movies_file))
            shutil.move(str(extracted_dir / "ratings.csv"), str(ratings_file))
            
            # Clean up
            shutil.rmtree(extracted_dir)
            zip_path.unlink()
        
        print("✅ MovieLens data downloaded and extracted!")
        return True
        
    except Exception as e:
        print(f"❌ Error downloading data: {e}")
        print("\n🔧 Manual download instructions:")
        print("1. Go to https://grouplens.org/datasets/movielens/")
        print("2. Download 'ml-latest-small.zip'")
        print("3. Extract and place movies.csv and ratings.csv in data/raw/")
        return False

def train_models_if_needed():
    """Train models if they don't exist."""
    models_dir = Path("models/saved_models")
    model_file = models_dir / "content_based_model.cbm"
    
    if model_file.exists():
        print("✅ Trained models already exist!")
        return True
    
    print("🤖 Training models (this may take a few minutes)...")
    
    try:
        # Run the main training script
        result = subprocess.run([sys.executable, "main.py"], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Models trained successfully!")
            return True
        else:
            print(f"❌ Training failed: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Error training models: {e}")
        return False

def launch_streamlit():
    """Launch the Streamlit application."""
    print("🚀 Launching Streamlit application...")
    
    try:
        # Save the Streamlit app to a file
        app_content = '''# This file will be created by the setup script
# The actual content is in the artifact above
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent))

# Import and run the app
from streamlit_app import main
main()
'''
        
        with open("run_streamlit.py", "w") as f:
            f.write(app_content)
        
        print("📱 Starting Streamlit server...")
        print("🌐 The app will open in your browser shortly...")
        print("⚠️  Note: You need to save the Streamlit app code from above as 'streamlit_app.py'")
        
        # Launch Streamlit
        subprocess.run([sys.executable, "-m", "streamlit", "run", "streamlit_app.py"])
        
    except Exception as e:
        print(f"❌ Error launching Streamlit: {e}")

def main():
    """Main setup function."""
    print("🎬 Movie Recommendation System Setup")
    print("=" * 50)
    
    # Step 1: Check packages
    check_and_install_packages()
    print()
    
    # Step 2: Download data
    if not download_movielens_data():
        print("❌ Setup failed: Could not download data")
        return
    print()
    
    # Step 3: Train models
    if not train_models_if_needed():
        print("❌ Setup failed: Could not train models")
        return
    print()
    
    # Step 4: Launch app
    print("🎉 Setup complete! Ready to launch demo.")
    print()
    
    launch_demo = input("Launch Streamlit demo now? (y/n): ").lower().strip()
    
    if launch_demo in ['y', 'yes']:
        launch_streamlit()
    else:
        print("\n📋 To launch the demo later, run:")
        print("   streamlit run streamlit_app.py")
        print("\n🔧 Make sure to save the Streamlit app code as 'streamlit_app.py' first!")

if __name__ == "__main__":
    main()