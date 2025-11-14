from PIL import Image
from io import BytesIO
import base64
from openai import OpenAI
import os
import soundfile as sf
from dotenv import load_dotenv
from voxcpm import VoxCPM


def encode_image(image_path):
    """Encodes an image to base64 for Ollama VLM."""
    with Image.open(image_path) as img:
        with BytesIO() as buffer:
            img.save(buffer, format="JPEG") # Or PNG, depending on your image
            return base64.b64encode(buffer.getvalue()).decode('utf-8')
        
# Load the API key from an environment variable
load_dotenv()
print("ENV KEY:", os.getenv("OPENAI_API_KEY"))
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def openai_do_problem(modelname, filename):
    # Example usage with an image
    image_path = r"C:/Users/vmanukyan135/MathTutor/math-problems/" + filename  # Fixed path
    encoded_image = encode_image(image_path)

    # Make an API call (e.g., chat completions)
    response = client.chat.completions.create(
        model=modelname,
        messages=[
            {
                'role': 'user',
                'content': [
                    {
                        "type": "text",
                        "text": 'You are a helpful tutor for a middle school student to learn math problem solving. ' \
                                + 'The image contains what you see from a camera. ' \
                                + 'The problem is at the top of the image. Solve the problem. ' \
                                + 'You should not be showing your thoughts but talking intuitively to the student. Decide whether you should talk to instruct the student. If yes, what would you say? ' \
                                + 'The goal is to improve the student knowledge and skills on solving similar math problems in the future.'
                    },
                    {
                        "type": "image_url",
                        "image_url": { "url": f"data:image/jpeg;base64,{encoded_image}"}
                    }
                ]
            }
        ]
    )
    print(response.choices[0].message.content)
    return (response.choices[0].message.content)

voice_sample_path = r"C:\Users\vmanukyan135\MathTutor\voices\sampleVoice.wav"  # Fixed with raw string
model = VoxCPM.from_pretrained("openbmb/VoxCPM-0.5B")
problem = r"C:\Users\vmanukyan135\MathTutor\math-problems"  # Fixed with raw string

for filename in ["p3.jpg"]:
    for modelname in ["gpt-4.1-mini"]:
        print('-'*5+modelname+'-'*5+filename+'-'*5)
        text_to_speak = openai_do_problem(modelname, filename)
        
        # Generate audio for this specific response
        output_path = f"response_{filename.replace('.jpg', '')}.wav"
        
        wav = model.generate(
            text=text_to_speak,
            prompt_wav_path=voice_sample_path,
            prompt_text=text_to_speak,
            cfg_value=2.0,                 
            inference_timesteps=10,        
            normalize=True,                
            denoise=True,                  
            retry_badcase=True,            
            retry_badcase_max_times=3,     
            retry_badcase_ratio_threshold=6.0,
        )
        
        sf.write(output_path, wav, 16000)
        print(f"Saved: {output_path}")