from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from PIL import Image
from io import BytesIO
import base64
from openai import OpenAI
import os
import torch
import soundfile as sf
from dotenv import load_dotenv
from voxcpm import VoxCPM
import uuid
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter app

# Configuration
UPLOAD_FOLDER = 'uploads'
OUTPUT_FOLDER = 'outputs'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

# Prevent ModelScope temp-file locking issues
os.environ["MODELSCOPE_CACHE"] = "C:/modelscope_cache"

# Load API key and set up client
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

GPT_MODEL_NAME = "gpt-4o-mini"
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Setup device
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

# Load VoxCPM model
print("Loading VoxCPM model...")
model = VoxCPM.from_pretrained("openbmb/VoxCPM-0.5B")
model = model.to(device)
print("VoxCPM model loaded successfully")

# Voice sample path
script_dir = os.path.dirname(os.path.abspath(__file__))
voice_sample_path = os.path.join(script_dir, "voices", "sampleVoice.wav")

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def encode_image(image_path):
    """Encodes the image file to a base64 string."""
    try:
        with Image.open(image_path) as img:
            with BytesIO() as buffer:
                img.save(buffer, format="JPEG")
                return base64.b64encode(buffer.getvalue()).decode("utf-8")
    except Exception as e:
        print(f"Error encoding image: {e}")
        return None

def solve_math_problem(image_path):
    """Sends the image to OpenAI API and returns the solution."""
    encoded_image = encode_image(image_path)
    
    if not encoded_image:
        return None, "Error: Could not encode image."

    rules_prompt = (
        "You are a friendly, encouraging, and patient math tutor for a middle school student. "
        "The problem is clearly visible in the image. Your primary goal is to teach, not just give the answer. "
        "DO NOT give the final answer first. "
        "Instead, break the solution into 3 to 5 clear, simple, and logical steps. "
        "For each step, explain the *why* in a simple way and ask a brief, guiding question "
        "at the end of the explanation, like 'Can you see why we need to do this first?' or 'What do you think is the next logical step?' "
        "Keep the language highly engaging for a middle schooler."
    )

    try:
        response = client.chat.completions.create(
            model=GPT_MODEL_NAME,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": rules_prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{encoded_image}"}
                        }
                    ]
                }
            ]
        )
        
        content = response.choices[0].message.content.strip()
        return content, None
    except Exception as e:
        return None, f"OpenAI API error: {str(e)}"

def generate_audio(text, output_path):
    """Generates audio from text using VoxCPM."""
    try:
        wav = model.generate(
            text=text,
            prompt_wav_path=voice_sample_path,
            inference_timesteps=100,
            cfg_value=2.0,
            normalize=True,
            denoise=False
        )
        sf.write(output_path, wav, 16000)
        return True
    except Exception as e:
        print(f"Audio generation error: {e}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'device': device,
        'model': GPT_MODEL_NAME
    })

@app.route('/solve', methods=['POST'])
def solve_problem():
    """
    Endpoint to solve math problem from uploaded image.
    Returns both text solution and audio file.
    """
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400
    
    file = request.files['image']
    
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if not allowed_file(file.filename):
        return jsonify({'error': 'Invalid file type. Use PNG, JPG, or JPEG'}), 400
    
    try:
        # Save uploaded image
        unique_id = str(uuid.uuid4())
        filename = secure_filename(f"{unique_id}_{file.filename}")
        image_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(image_path)
        
        # Solve the problem
        solution_text, error = solve_math_problem(image_path)
        
        if error:
            return jsonify({'error': error}), 500
        
        # Generate audio
        audio_filename = f"{unique_id}_solution.wav"
        audio_path = os.path.join(OUTPUT_FOLDER, audio_filename)
        
        audio_success = generate_audio(solution_text, audio_path)
        
        if not audio_success:
            return jsonify({'error': 'Failed to generate audio'}), 500
        
        # Clean up uploaded image
        os.remove(image_path)
        
        return jsonify({
            'success': True,
            'solution': solution_text,
            'audio_id': unique_id,
            'message': 'Problem solved successfully!'
        })
        
    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500

@app.route('/audio/<audio_id>', methods=['GET'])
def get_audio(audio_id):
    """Endpoint to download generated audio file."""
    try:
        audio_filename = f"{audio_id}_solution.wav"
        audio_path = os.path.join(OUTPUT_FOLDER, audio_filename)
        
        if not os.path.exists(audio_path):
            return jsonify({'error': 'Audio file not found'}), 404
        
        return send_file(audio_path, mimetype='audio/wav')
        
    except Exception as e:
        return jsonify({'error': f'Error retrieving audio: {str(e)}'}), 500

@app.route('/cleanup/<audio_id>', methods=['DELETE'])
def cleanup_audio(audio_id):
    """Endpoint to clean up generated audio files."""
    try:
        audio_filename = f"{audio_id}_solution.wav"
        audio_path = os.path.join(OUTPUT_FOLDER, audio_filename)
        
        if os.path.exists(audio_path):
            os.remove(audio_path)
            return jsonify({'success': True, 'message': 'Audio file deleted'})
        else:
            return jsonify({'error': 'Audio file not found'}), 404
            
    except Exception as e:
        return jsonify({'error': f'Error deleting audio: {str(e)}'}), 500

if __name__ == '__main__':
    print("=" * 50)
    print("Math Tutor API Server")
    print("=" * 50)
    print(f"Device: {device}")
    print(f"Model: {GPT_MODEL_NAME}")
    print(f"Voice sample: {voice_sample_path}")
    print(f"Server starting on http://localhost:5000")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)