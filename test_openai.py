from PIL import Image
from io import BytesIO
import base64
from openai import OpenAI
import os
import torch
import soundfile as sf
from dotenv import load_dotenv
from voxcpm import VoxCPM

# Prevent ModelScope temp-file locking issues
os.environ["MODELSCOPE_CACHE"] = "C:/modelscope_cache"

# Load API key and set up client
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

# Using the more stable and cheaper gpt-4o-mini for vision/text tasks
GPT_MODEL_NAME = "gpt-4o-mini" 
print("Using " + GPT_MODEL_NAME + " Model")

# OPENAI CLIENT API KEY IN ENV FILE
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Setup to use CUDA if available, otherwise CPU
device = "cuda" if torch.cuda.is_available() else "cpu"
print("Using device: " + device)

# Load VoxCPM model
model = VoxCPM.from_pretrained("openbmb/VoxCPM-0.5B")
print("VOXCPM MODEL IS LOADED")

# Path to the voice sample for cloning

script_dir = os.path.dirname(os.path.abspath(__file__))
voice_sample_path = os.path.join(script_dir, "voices", "sampleVoice.wav")

# Make sure this prints the correct path
print(f"DEBUG: Voice sample path = {voice_sample_path}")
print(f"DEBUG: File exists = {os.path.exists(voice_sample_path)}")

def encode_image(image_path):
    """Encodes the image file to a base64 string."""
    try:
        with Image.open(image_path) as img:
            with BytesIO() as buffer:
                # Ensure it's saved as JPEG for consistent encoding
                img.save(buffer, format="JPEG")
                return base64.b64encode(buffer.getvalue()).decode("utf-8")
    except FileNotFoundError:
        print(f"Error: Image file not found at {image_path}")
        return None

# Use OpenAI key to solve the problem
def openai_do_problem(modelname, filename):
    """Sends the image and the rules prompt to the OpenAI API."""
    # Use the correct path relative to your GitHub folder
    script_dir = os.path.dirname(os.path.abspath(__file__))
    image_path = os.path.join(script_dir, "math_Samples", filename)
    encoded_image = encode_image(image_path)
    
    if not encoded_image:
        return "Error: Could not encode image."

    # PROMPT
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
            model=modelname,
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
        print("\n====== AI Response ======\n")
        print(content)
        return content
    except Exception as APIERROR:
        print(f"An error occurred during OpenAI call: {APIERROR}")
        return "Encountered an error WHILE solving that problem."

# Loop through all the problems and generate audio responses for the solutions
for filename in ["p3.jpg"]:
    modelname = GPT_MODEL_NAME
    print('-' * 5 + modelname + '-' * 5 + filename + '-' * 5)
    text_to_speak = openai_do_problem(modelname, filename)

    # Add 4 spaces of indentation here!
    if not text_to_speak.startswith("Error:") and not text_to_speak.startswith("Sorry,") and not text_to_speak.startswith("Encountered"):
        output_path = f"response_{filename.replace('.jpg', '')}_{modelname}.wav"
        
        print("GENERATING AUDIO WITH VOXCPM")
        try:
            wav = model.generate(
                text=text_to_speak,
                prompt_wav_path=voice_sample_path,
                inference_timesteps=100, 
                cfg_value=2.0,
                normalize=True,
                denoise=False 
            )
            sf.write(output_path, wav, 16000)
            print(f"Successfully saved audio: {output_path}")
        except Exception as e:
            print(f"An error occurred during VoxCPM generation: {e}")
        
        print('\n' + '=' * 40 + '\n')