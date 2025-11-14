import soundfile as sf
import numpy as np
from voxcpm import VoxCPM

model = VoxCPM.from_pretrained("openbmb/VoxCPM-0.5B")

# Read the original audio file
print("Loading original audio...")
original_audio, sr = sf.read("C:/Users/vmanukyan135/MathTutor/Owen.wav")

# Clean/denoise the audio
print("Cleaning audio...")
cleaned_audio = model.denoiser.enhance(original_audio, sr)

# Save the cleaned version
output_path = "C:/Users/vmanukyan135/MathTutor/Owen_cleaned.wav"
sf.write(output_path, cleaned_audio, sr)
print(f"Cleaned audio saved to: {output_path}")

# Non-streaming
wav = model.generate(
    text="My name is Owen. I like machine learning.",
    # text="I love large language models. I think this is an amazing technology. I hope I can have an AI tutor for my middle school child.",
    prompt_wav_path="C:/Users/vmanukyan135/MathTutor/Owen_cleaned.wav",      # optional: path to a prompt speech for voice cloning
    cfg_value=2.0,             # LM guidance on LocDiT, higher for better adherence to the prompt, but maybe worse
    inference_timesteps=10,   # LocDiT inference timesteps, higher for better result, lower for fast speed
    normalize=True,           # enable external TN tool
    denoise=True,             # enable external Denoise tool
    retry_badcase=True,        # enable retrying mode for some bad cases (unstoppable)
    retry_badcase_max_times=3,  # maximum retrying times
    retry_badcase_ratio_threshold=6.0, # maximum length restriction for bad case detection (simple but effective), it could be adjusted for slow pace speech
)

# sf.write("phmvoice2024_tutor.wav", wav, 16000)
sf.write("output.wav", wav, 16000)
# print("saved: phmvoice2024_tutor.wav")
print("saved: output.wav")