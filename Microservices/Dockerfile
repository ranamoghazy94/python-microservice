# Use a lightweight Python base image
FROM python:3.9-slim

# Copy dependencies file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code into the container
COPY . .

# Expose the Flask port
EXPOSE 5000

# Command to run the Flask application
ENTRYPOINT ["python", "run.py"]
