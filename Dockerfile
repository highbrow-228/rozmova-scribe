FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.9.7 /uv /bin/uv

WORKDIR /app

# кеш uv у mount, а не в образі: перезбірка не качає torch наново
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    UV_CACHE_DIR=/root/.cache/uv uv sync --frozen

COPY run.sh run-wav.sh run-batch.sh cmp.sh sitecustomize.py ./

# скрипти кладуть тимчасовий .wav поруч із собою, а контейнер працює від
# користувача хоста: записуваною робимо саму теку, вміст лишається root'івським
RUN chmod 1777 /app

# HF_HOME - у примонтованому кеші, щоб ваги качались один раз; решта - щоб
# бібліотеки не лізли писати в $HOME, якого у цього користувача немає
ENV HF_HOME=/app/cache/hf-cache \
    XDG_CACHE_HOME=/tmp \
    MPLCONFIGDIR=/tmp/matplotlib

CMD ["./run-batch.sh"]
