# Manual Técnico: Sistema de Rádio 98.5 FM, Som 3D & Caixas de Som (`vp_newspaper`)

Este documento detalha toda a arquitetura, contratos de rede, processamento de áudio em CEF/NUI, sincronização espacial tridimensional e absorção da engenharia do Rahe Speakers dentro do `vp_newspaper`.

---

## 📻 1. Visão Geral da Arquitetura de Áudio

O ecossistema sonoro do `vp_newspaper` unifica rádio global sintonizável, caixas de som físicas portáteis e sistemas de som automotivo em uma única camada de execução:

```
                                  ┌───────────────────────────────┐
                                  │      SERVIDOR (server/radio.lua)│
                                  │  - StationState (Mesa DJ)     │
                                  │  - ActiveGroundSpeakers       │
                                  │  - AttachedVehicleSpeakers    │
                                  └───────────────┬───────────────┘
                                                  │
                 ┌────────────────────────────────┴────────────────────────────────┐
                 │ Sync Events & StateBags (weazelVehicleSpeaker, weazelCarryingRadio)│
                 ▼                                                                 ▼
      ┌──────────────────────────────┐                          ┌──────────────────────────────┐
      │   CLIENTE A (client/radio.lua)│                          │   CLIENTE B (client/radio.lua)│
      │  - Adaptive Ticking Loop     │                          │  - Adaptive Ticking Loop     │
      │  - Cálculo de Distância 3D   │                          │  - Cálculo de Distância 3D   │
      └──────────────┬───────────────┘                          └──────────────┬───────────────┘
                     │                                                         │
                     ▼                                                         ▼
      ┌──────────────────────────────┐                          ┌──────────────────────────────┐
      │   NUI CEF (web/radio_audio.js)│                         │   NUI CEF (web/radio_audio.js)│
      │  - YouTube IFrame API        │                          │  - YouTube IFrame API        │
      │  - Web Audio 5-Band Biquad EQ│                          │  - Web Audio 5-Band Biquad EQ│
      │  - Streamer Safety Filter    │                          │  - Streamer Safety Filter    │
      └──────────────────────────────┘                          └──────────────────────────────┘
```

---

## 🎶 2. Suporte Nativo a Playlists do YouTube

O motor em `web/radio_audio.js` processa URLs de forma inteligente:

### 2.1. Extração e Detecção
```javascript
function extractYouTubePlaylistId(url) {
    if (!url) return null;
    const match = url.match(/[?&]list=([a-zA-Z0-9_-]+)/);
    return match ? match[1] : null;
}
```
* **Links de Playlist:** `https://www.youtube.com/playlist?list=PL...` ou `https://www.youtube.com/watch?v=XYZ&list=PL...`
* Ao identificar o parâmetro `list=`, a API IFrame do YouTube é instruída a carregar a lista completa:
```javascript
ytPlayer.loadPlaylist({
    list: playlistId,
    listType: 'playlist',
    index: 0,
    startSeconds: startSeconds
});
```

### 2.2. Transição Automática de Faixa
No evento `onStateChange`, quando uma faixa termina (`YT.PlayerState.ENDED`), o script verifica se ainda há vídeos restantes na lista:
```javascript
if (event.data === YT.PlayerState.ENDED) {
    if (ytPlayer && ytPlayer.getPlaylist && ytPlayer.getPlaylistIndex) {
        const list = ytPlayer.getPlaylist();
        const idx = ytPlayer.getPlaylistIndex();
        if (list && idx !== -1 && idx < list.length - 1) {
            return; // Continua tocando a próxima faixa da playlist automaticamente
        }
    }
    notifyTrackEnded(); // Avisa o servidor apenas quando a playlist inteira esgotar
}
```

---

## 🎚️ 3. Equalizador Paramétrico Biquad de 5 Bandas

O áudio HTML5 passa por um grafo em cascata serial na Web Audio API:

```
[MediaElementSource] 
       │
       ▼
 [Low: 80Hz Lowshelf] 
       │
       ▼
 [Low-Mid: 250Hz Peaking] 
       │
       ▼
 [Mid: 1000Hz Peaking] 
       │
       ▼
 [High-Mid: 4000Hz Peaking] 
       │
       ▼
 [High: 12000Hz Highshelf] 
       │
       ▼
 [AudioDestination (Alto-falantes)]
```

### Presets Integrados:
| Preset | Low (80Hz) | Low-Mid (250Hz) | Mid (1kHz) | High-Mid (4kHz) | High (12kHz) | Finalidade Principal |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Broadcast FM** | $+2\text{dB}$ | $+1\text{dB}$ | $+4\text{dB}$ | $+2\text{dB}$ | $+1\text{dB}$ | Assinatura padrão de rádio comercial |
| **Bass Boost** | $+8\text{dB}$ | $+4\text{dB}$ | $0\text{dB}$ | $-1\text{dB}$ | $-2\text{dB}$ | Paredão e som automotivo pesado |
| **Vocal & Notícias** | $-2\text{dB}$ | $0\text{dB}$ | $+5\text{dB}$ | $+3\text{dB}$ | $+1\text{dB}$ | Entrevistas e coberturas ao vivo |
| **Club & Balada** | $+6\text{dB}$ | $+2\text{dB}$ | $-1\text{dB}$ | $+3\text{dB}$ | $+5\text{dB}$ | Música eletrônica e festas |
| **Outdoor / PA** | $+4\text{dB}$ | $+2\text{dB}$ | $+2\text{dB}$ | $+4\text{dB}$ | $+6\text{dB}$ | Eventos abertos e projeção externa |
| **Flat** | $0\text{dB}$ | $0\text{dB}$ | $0\text{dB}$ | $0\text{dB}$ | $0\text{dB}$ | Resposta linear sem alteração |

---

## 👥 4. Áudio Tridimensional Multi-Player

### 4.1. Prioridades de Reprodução Local
No cliente (`UpdateRadioPlayback` em `client/radio.lua`), o volume é calculado segundo uma hierarquia estrita:

1. **Fones de Ouvido (`headphones`):** Prioridade máxima. Volume direto do usuário ($100\%$), sem queda por distância.
2. **Carregando Caixa no Braço/Ombro:** O ped está com a caixa nas mãos. Volume direto ($100\%$) e replicação do estado `weazelCarryingRadio` para outros jogadores ouvirem.
3. **Dentro de Veículo com Rádio Ligado:** Volume direto ($100\%$).
4. **Fontes Tridimensionais Externas:**
   - Caixas de som colocadas no chão (`ActiveGroundSpeakers`): até 25 metros.
   - Outros jogadores carregando boombox no ombro: até 25 metros.
   - Veículos com sistema de som instalado: até 30 metros.

### 4.2. Fórmula de Atenuação Quadrática Suave
Para evitar cortes abruptos no áudio ao caminhar, a atenuação segue uma curva quadrática:

$$\text{Fator} = \max\left(0, 1.0 - \frac{\text{dist}}{\text{maxAudible}}\right)$$
$$\text{VolumeFinal} = \text{UserVolume} \times (\text{Fator})^2$$

Essa curva garante que o som seja potente perto da caixa e diminua naturalmente até o silêncio nos limites de alcance.

---

## 🚗 5. Sistema de Som Veicular (Rahe Engineering)

Permite fixar a caixa de som em 3 pontos configurados no veículo via `ox_target`:

```lua
local ATTACH_CONFIGS = {
    trunk = {
        bone = 'boot',
        fallbackBone = 'bodyshell',
        offset = vector3(0.0, -1.85, 0.2),
        rot = vector3(0.0, 0.0, 0.0)
    },
    roof = {
        bone = 'roof',
        fallbackBone = 'bodyshell',
        offset = vector3(0.0, -0.2, 0.85),
        rot = vector3(0.0, 0.0, 0.0)
    },
    bed = {
        bone = 'bodyshell',
        fallbackBone = 'bodyshell',
        offset = vector3(0.0, -1.3, 0.3),
        rot = vector3(0.0, 0.0, 0.0)
    }
}
```

### Contrato de Segurança Server-Side:
- **Verificação de Proximidade:** O ped do instalador deve estar a $\le 6.0\text{m}$ do veículo.
- **Verificação de Estado:** O veículo deve estar parado e ser uma entidade válida sincronizada no servidor.
- **StateBag Replicada:** O servidor atribui `Entity(veh).state:set('weazelVehicleSpeaker', data, true)`.
- **Cleanup Automático:** Ao parar o recurso ou despawnar o veículo, as props são deletadas automaticamente.

---

## 🏃 6. Carregamento Manual de Boombox (Carry System)

Ao usar o item `radio_portable`, o jogador pode escolher **"Carregar no Braço / Ombro"**:
- **Bone:** `SKEL_R_Hand` (Bone Index 28422) com offsets ajustados.
- **Animação:** `anim@heists@box_carry@` / `idle` (flag 49 - tronco superior sem travar as pernas).
- **StateBag:** `LocalPlayer.state:set('weazelCarryingRadio', true, true)`.
- **Ações Rápidas em Teclado:**
  - `[E]` Colocar no chão imediatamente.
  - `[G]` Instalar no veículo mais próximo.
  - `[X]` Cancelar e guardar de volta na mochila.
- **Recolhimento de Caixa do Chão:**
  - Comando `/pegarcaixa` ou `/recolhersom`.
  - Interação via `ox_target` no prop `prop_boombox_01`.

---

## 🛡️ 7. Modo Streamer Anti-DMCA

Comandos `/modostreamer`, `/streamermode` e `/safetypreference`:
* Permite que criadores de conteúdo ativem a proteção contra direitos autorais.
* O estado é salvo permanentemente no armazenamento local do cliente (`KVP`).
* Quando ativado, transmissões comerciais têm o multiplicador zerado no cliente do streamer, enquanto jogadores ao redor continuam ouvindo normalmente.

---

## 🔊 8. Tiers de Caixas de Som & Especificações Técnicas (RAHE Architecture)

O sistema possui 4 classes distintas de caixas de som configuradas em `shared/config.lua` e integradas ao `ox_inventory`:

| Modelo ID | Nome Comercial | Alcance Máx | Potência | Tipo de Transporte | Prop 3D Hash | Preço na Loja |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| `retro` | **Boombox Retrô 1986** | 30.0m | 85% | Ombro (`shoulder`) | `prop_boombox_01` | \$250 |
| `vibe` | **CyberBoombox RGB** | 40.0m | 100% | Ombro (`shoulder`) | `prop_boombox_01` | \$750 |
| `beat` | **Torre SoundBeat Pro** | 60.0m | 130% | Duas Mãos (`carry_two_hands`) | `v_res_audiotower` | \$1,800 |
| `blast` | **Estádio Blast PA System**| 90.0m | 180% | Duas Mãos (`carry_two_hands`) | `prop_speaker_06` | \$4,500 |

* **Anti-Downgrade:** Ao recolher uma caixa do chão para o inventário (`/recolhersom`), o item exato correspondente ao modelo é devolvido via `ox_inventory`.

---

## 🛒 9. Loja de Caixas de Som (/lojasom)

Os jogadores podem adquirir caixas físicas na loja de equipamentos:
* **Localização Padrão:** Praça Central de Legion Square (`-42.53, -1039.37, 27.41, heading 204.0`).
* **NPC Interativo:** Ped vendedor fixado com `ox_target` ("Ver Catálogo de Caixas de Som").
* **Comando Direto:** `/lojasom` para abrir o catálogo.
* **Fail-Closed Economy:** A cobrança em dinheiro/banco ocorre no servidor antes da entrega do item; caso o jogador não tenha saldo ou espaço no inventário, a transação aborta sem duplicar itens.

---

## 📐 10. Pré-Visualização Tridimensional de Posicionamento (Gizmo 3D)

Ao usar uma caixa de som e selecionar "Colocar no Chão", entra em vigor o modo de posicionamento interativo em tempo real:
* **Ghost Object:** Prop semitransparente acompanha o olhar e raycast do solo do jogador.
* **Controles no TextUI:**
  * `[Q] / [E]` — Gira a caixa no eixo Z (Heading).
  * `[ENTER]` — Confirma o posicionamento físico.
  * `[X]` — Cancela o posicionamento e devolve o item.

---

## 📜 11. Sistema de Fila de Músicas (Queue) & Histórico

* **Fila de Reprodução (Queue):**
  * Submenu `OpenSpeakerQueueMenu` em cada caixa ou grupo.
  * Permite adicionar músicas por URL com título opcional.
  * Botão de pular faixa (`⏭ Pular para Próxima Faixa`).
  * Avanço automático garantido pelo callback NUI `radioTrackEnded` emitido pelo CEF ao término do vídeo no YouTube.
* **Histórico de Reprodução:**
  * Tabela `newspaper_speaker_history` salva automaticamente cada reprodução de música.
  * Submenu `OpenSpeakerHistoryMenu` com lista das últimas faixas e reprodução instantânea em 1 clique.

---

## 🔒 12. Segurança e Controle por PIN (4 Dígitos)

Cada caixa possui controle de acesso com 3 níveis configuráveis pelo proprietário:
1. **Público (`public`):** Qualquer cidadão próximo pode abrir o menu e alterar faixas ou volumes.
2. **Privado (`owner_only`):** Apenas o jogador que colocou a caixa tem autorização para manipulá-la.
3. **Protegido por PIN (`pin`):** Exige a digitação de uma senha de 4 a 8 dígitos via `lib.inputDialog`. A validação é realizada via callback seguro no servidor (`validateSpeakerAccess`).

---

## 🏛 13. Caixas Permanentes no Banco de Dados

* Permite que administradores fixem caixas de som para eventos ou praças que persistam mesmo após reinicializações do servidor.
* **Tabela SQL:** `newspaper_permanent_speakers` armazena coordenadas tridimensionais, rotação, volume padrão, alcance, nome do local e modo de segurança.
* **Ciclo de Vida:** Carregadas no boot do servidor (`onResourceStart` e `migrationsComplete`) e sincronizadas com todos os clientes conectados. Props são criadas com freeze de física e interações `ox_target`.

---

## 🎶 14. Grupos de Caixas de Som (Speaker Groups Architecture)

Inspirado na arquitetura do Rahe Speakers, permite que múltiplos pontos sonoros toquem a **mesma música em perfeita sincronia**:
* **Tabela SQL:** `newspaper_speaker_groups` (id, nome, connect_code, access_code, owner_cid).
* **Connect Code:** Código público (ex: `PRAIA1`) que qualquer caixa pode usar para se vincular ao grupo.
* **Access Code:** Código privado que concede acesso ao painel de controle do grupo (tocar música, pausar, avançar fila).
* **Sincronização 3D:** Cada caixa pertencente ao grupo calcula sua distância individual em relação ao jogador, mas consome o fluxo de áudio, URL e timestamp unificados do grupo.
* **Comando:** `/caixasomgrupo` para abrir o painel master de grupos.

---

## 🚗 15. Oclusão Acústica Veicular (Cabin Muffle)

* No loop `UpdateRadioPlayback`, quando um jogador entra em um veículo fechado (`GetVehiclePedIsIn`), qualquer som proveniente de caixas externas (chão, ombros ou outros carros) sofre **atenuação de $65\%$** no volume.
* O sistema aplica dinamicamente o preset de equalização `vocal`/low-pass no WebAudio, abafando os agudos e reproduzindo com fidelidade o isolamento acústico da lataria e dos vidros fechados do carro.

---

## 🛠 16. Painel de Administração Master (/speakersadmin & /killallspeakers)

* **`/speakersadmin`:**
  * Painel restrito a administradores (via permissão Ace / `group.admin`).
  * Lista todas as caixas de som ativas na cidade (chão, ombro, instaladas em veículos ou permanentes no banco).
  * Exibe status de reprodução, distância e coordenadas.
  * Ações rápidas: **Teleportar até a Caixa** e **Deletar / Remover Caixa Remotamente**.
* **`/killallspeakers`:**
  * Comando de emergência para servidores de alto fluxo.
  * Interrompe imediatamente todas as caixas, zera estados de áudio e silencia todos os clientes simultaneamente.
