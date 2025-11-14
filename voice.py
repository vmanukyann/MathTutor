import soundfile as sf
import numpy as np
from voxcpm import VoxCPM

model = VoxCPM.from_pretrained("openbmb/VoxCPM-0.5B")

# Non-streaming
wav = model.generate(
    text="My name is Vazgen. I like machine learning.",
    # text="I love large language models. I think this is an amazing technology. I hope I can have an AI tutor for my middle school child.",
    prompt_wav_path="C:/Users/vmanukyan135/MathTutor/sampleVoice.wav",      # optional: path to a prompt speech for voice cloning
    prompt_text="Thank you Mrs. Secor and Mr. Neith and the Pennquire, graduates, parents and guests on behalf of the Penn Harris Madison School Board of Trustees, the administration, faculty and staff of Penn High School, it is my distinct pleasure to welcome you to the 65th Penn High School commencement ceremony, it is also my pleasure to introduce our special guests seated on the stage this afternoon, Dr. Jerry Thacker, BHM superintendent.",          # optional: reference text
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