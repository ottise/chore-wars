FROM python:3.12-slim
WORKDIR /service
COPY pyproject.toml ./
COPY requirements.lock ./
COPY app ./app
RUN pip install --no-cache-dir -r requirements.lock && pip install --no-cache-dir --no-deps .
COPY alembic.ini ./
COPY migrations ./migrations
RUN useradd --create-home ai && mkdir /artifacts && chown ai:ai /artifacts
USER ai
ENV AI_ARTIFACTS=/artifacts
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
