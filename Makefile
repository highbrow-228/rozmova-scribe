IMAGE ?= transcribe
MODEL ?= large-v2
TAG   ?=

# Примусово на процесорі: make run GPU=
GPU ?= $(shell command -v nvidia-smi >/dev/null 2>&1 && echo --gpus all)

# SPEAKER_NUM=3 make one FILE=... - змінні оточення make бачить як власні
# й передає далі. Незадані не передаємо взагалі: -e VAR= затерло б
# значення з .env порожнім рядком.
PASS := LANGUAGE SPEAKER_NUM OUTPUT_FORMAT HOTWORDS INITIAL_PROMPT DEVICE COMPUTE_TYPE
ENV  := $(foreach v,$(PASS),$(if $($(v)),-e $(v)='$($(v))'))

# у контейнері корінь інший, тож абсолютний шлях з хоста зводимо до
# відносного від кореня проєкту
FILE_REL = $(patsubst $(CURDIR)/%,%,$(FILE))

DIRS := data/wav_need_to_run data/wav_done data/transcripts cache/hf-cache

# -t лише за живого термінала: інакше docker падає з "the input device is not a TTY"
TTY := $(shell [ -t 0 ] && echo -it)

# -u: інакше транскрипти в data/ належали б root
DOCKER_RUN = docker run --rm $(TTY) $(GPU) $(ENV) \
	-u $(shell id -u):$(shell id -g) \
	-v $(CURDIR)/data:/app/data \
	-v $(CURDIR)/cache/hf-cache:/app/cache/hf-cache \
	-v $(CURDIR)/.env:/app/.env:ro \
	$(IMAGE)

.PHONY: help build run one video shell

help:
	@echo 'make build                                   зібрати образ'
	@echo 'make run                                     прогнати все з data/wav_need_to_run/'
	@echo 'make one FILE=data/wav_need_to_run/запис.wav один запис .wav'
	@echo 'make video FILE=data/нарада.mkv              витягти звук з відео і транскрибувати'
	@echo 'make shell                                   баш усередині контейнера'
	@echo
	@echo 'модель і мітка: make run MODEL=large-v3-turbo TAG=vad15'
	@echo 'на процесорі:   make run GPU='

build:
	docker build -t $(IMAGE) .

# теки має створити хост: докер зробив би їх від root
$(DIRS):
	mkdir -p $@

.env:
	@echo 'немає .env - скопіюй: cp .env.example .env і впиши HF_TOKEN'; exit 1

run: .env $(DIRS)
	$(DOCKER_RUN) ./run-batch.sh $(MODEL) $(TAG)

one: .env $(DIRS)
	@[ -n "$(FILE)" ] || { echo 'вкажи файл: make one FILE=data/wav_need_to_run/запис.wav'; exit 1; }
	$(DOCKER_RUN) ./run-wav.sh '$(FILE_REL)' $(MODEL) $(TAG)

video: .env $(DIRS)
	@[ -n "$(FILE)" ] || { echo 'вкажи файл: make video FILE=data/нарада.mkv'; exit 1; }
	$(DOCKER_RUN) ./run.sh '$(FILE_REL)' $(MODEL) $(TAG)

shell: .env $(DIRS)
	$(DOCKER_RUN) bash
