# Prompts de geração das cartas (28)

**Estilo base** (cole no início de TODO prompt):
> Vertical collectible trading card artwork, satirical Los Santos / GTA-style illustration,
> vintage newspaper aesthetic, dramatic lighting, character/scene centered, clean margin around
> the edges for a frame, painterly comic style. NO text, NO logos, NO watermark.

**Specs:** proporção **2:3**, salvar em `web/cards/<arquivo>.png`, depois preencher `image='cards/<arquivo>.png'`
no `Config.Collectibles.cards[<id>]`. Lendárias = aura dourada/premium; raras = leve brilho.

---

## Set: Redação
- **reporter.png** (comum) — young rookie journalist with press badge and notepad, busy city street.
- **editor.png** (comum) — older editor-in-chief with glasses at a cluttered newsroom desk.
- **photog.png** (comum) — press photographer holding a big camera with flash, night city, paparazzi vibe.
- **paperboy.png** (comum) — teen paperboy on a bicycle tossing rolled newspapers, suburban street at dawn.
- **columnist.png** (rara) — flamboyant tabloid columnist at a vintage typewriter, smoke, golden accents.
- **anchor.png** (rara) — polished TV news anchor at a studio desk, on-air lights, confident.
- **presstycoon.png** (lendária) — powerful media mogul in a luxurious office, city skyline, golden legendary aura.

## Set: Personalidades de LS
- **dj.png** (comum) — late-night DJ at the turntables, neon club lights.
- **influencer.png** (comum) — social-media influencer taking a selfie, ring light, trendy.
- **athlete.png** (comum) — local sports athlete celebrating, stadium background.
- **chef.png** (comum) — star chef plating a dish in a fancy kitchen.
- **actor.png** (rara) — glamorous Vinewood actor on a red carpet, flashes, golden glow.
- **tycoon.png** (rara) — real-estate tycoon in a sharp suit in front of skyscrapers.
- **mayor.png** (lendária) — pompous city mayor at a podium in a grand civic hall, legendary golden aura.

## Set: Manchetes / Crimes
- **pickpocket.png** (comum) — sneaky pickpocket lifting a wallet in a crowd.
- **streetrace.png** (comum) — illegal night street race, two tuned cars, motion blur.
- **protest.png** (comum) — downtown protest crowd with signs (blank signs, NO text).
- **storm.png** (comum) — dramatic coastal storm hitting the city skyline, lightning.
- **heist.png** (rara) — masked robbers fleeing a bank with cash bags, action scene.
- **prisonbreak.png** (rara) — prison break at night, searchlights and fence, tense.
- **scandal.png** (lendária) — explosive political scandal, flashing cameras on a disgraced official, golden aura.

## Set: Lugares Icônicos
- **vinewood.png** (comum) — iconic hillside hilltop sign overlooking the city at sunset (NO real text).
- **pier.png** (comum) — seaside amusement pier with a ferris wheel at dusk.
- **observatory.png** (comum) — domed observatory on a hill above the city at night.
- **market.png** (comum) — bustling central street market stalls.
- **bank.png** (rara) — imposing central bank skyscraper, dramatic low angle.
- **lighthouse.png** (rara) — lone coastal lighthouse with beam over the sea at night.
- **casino.png** (lendária) — glamorous diamond casino exterior glowing at night, golden legendary aura.

---

## Como gerar aqui (quando houver cota)
A API do Gemini precisa de cota/billing ativo (free tier de imagem = 0). Com cota, peça:
"gere as 28 cartas com esses prompts em 2:3 e salve em web/cards/". Enquanto não houver arte,
as cartas funcionam com o emoji `art` do catálogo.
