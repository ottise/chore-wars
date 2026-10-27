FROM python:3.12.14-slim
ARG BUILD_COMMIT=unknown
ENV BUILD_COMMIT=$BUILD_COMMIT
WORKDIR /service
COPY requirements.lock ./
RUN pip install --no-cache-dir -r requirements.lock
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --no-deps .
RUN pip check
COPY alembic.ini ./
COPY migrations ./migrations
RUN useradd --create-home ai && mkdir /artifacts && chown ai:ai /artifacts
USER ai
ENV AI_ARTIFACTS=/artifacts
CMD ["/bin/sh", "-c", "exec uvicorn app.main:create_app --factory --host 0.0.0.0 --port ${PORT:-8000}"]
