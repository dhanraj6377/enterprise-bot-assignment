FROM python:3.12.7-slim-bookworm AS builder
WORKDIR /app
COPY . /app

FROM python:3.12.7-slim-bookworm AS runtime
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app --create-home --home-dir /home/app app \
    && chown -R app:app /app

COPY --from=builder /app /app

USER app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

EXPOSE 8080
CMD ["python", "app.py"]
