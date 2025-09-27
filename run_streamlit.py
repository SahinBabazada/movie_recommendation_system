# This file will be created by the setup script
# The actual content is in the artifact above
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parent))

# Import and run the app
from streamlit_app import main
main()
