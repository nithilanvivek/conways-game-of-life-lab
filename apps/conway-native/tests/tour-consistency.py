import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
tour=json.loads((root/'shared/tour.json').read_text())
assert len(tour)==17
assert next(step for step in tour if step['title']=='Edit selected cells')['area']==''
assert all(all(word not in (step['title']+' '+step['text']).lower() for word in ['no app fullscreen','v2','python']) for step in tour)
# Check the generated Linux copy has the same steps and platform modifier.
rows=(root/'linux/tour.h').read_text().split('static const TourStep tour_steps[]={',1)[1].split('};',1)[0]
linux=[json.loads('['+line.strip().rstrip(',')[1:-1]+']') for line in rows.splitlines() if line.strip().startswith('{')]
assert linux==[[step['title'],step['area'],step['text'].replace('{MOD}','Ctrl')] for step in tour]
print('PASS: 17 shared/Linux tour steps, keyboard-only step has no target, updated zoom copy')
