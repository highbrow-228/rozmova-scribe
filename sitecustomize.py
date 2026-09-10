import torch.serialization
from pyannote.audio.core.task import Specifications
torch.serialization.add_safe_globals([Specifications])
