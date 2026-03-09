from fastapi import FastAPI

app = FastAPI(title="Internview AI Analysis Service", version="1.0.0")

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/api/v1/analyze")
def analyze_video():
    # TODO: Implement Whisper audio extraction and speech-to-text here
    return {"message": "Analysis endpoint placeholder"}
