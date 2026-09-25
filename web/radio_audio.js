// ==========================================================
// Weazel News Radio: Audio Engine (Web Audio & YouTube API)
// Hardened with 5-Band Biquad Parametric EQ & Streamer Safety Mode
// Inspired by Rahe Speakers Audio Architecture
// ==========================================================

let ytPlayer = null;
let ytReady = false;
let currentSourceType = null; // 'youtube' | 'html5' | null
let html5Audio = null;
let baseVolume = 0.65;
let currentVolume = 0.65;
let isAttenuated = false;
let attenuationFactor = 1.0;
let streamerSafetyFactor = 1.0; // 1.0 = All, 0.0 = Muted/DMCA
let resourceName = 'vp_newspaper';

// Web Audio API context for 5-Band Equalizer & Acoustic Filters
let audioCtx = null;
let mediaSourceNode = null;
let eqNodes = {
    low: null,      // 80Hz Lowshelf
    lowMid: null,   // 250Hz Peaking
    mid: null,      // 1000Hz Peaking
    highMid: null,  // 4000Hz Peaking
    high: null      // 12000Hz Highshelf
};

const EQ_PRESETS = {
    flat: { low: 0, lowMid: 0, mid: 0, highMid: 0, high: 0 },
    broadcast: { low: 2, lowMid: 1, mid: 4, highMid: 2, high: 1 }, // Assinatura Weazel News FM
    bass: { low: 8, lowMid: 4, mid: 0, highMid: -1, high: -2 },     // Graves profundos para som automotivo
    vocal: { low: -2, lowMid: 0, mid: 5, highMid: 3, high: 1 },     // Foco em voz e notícias
    club: { low: 6, lowMid: 2, mid: -1, highMid: 3, high: 5 },      // Graves e agudos acentuados
    outdoor: { low: 4, lowMid: 2, mid: 2, highMid: 4, high: 6 }     // Caixas externas e eventos
};

function initWebAudio() {
    if (audioCtx) return;
    try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        audioCtx = new AudioContext();

        html5Audio = document.getElementById('html5-player');
        if (html5Audio) {
            mediaSourceNode = audioCtx.createMediaElementSource(html5Audio);

            // 1. Low: 80Hz Lowshelf
            eqNodes.low = audioCtx.createBiquadFilter();
            eqNodes.low.type = 'lowshelf';
            eqNodes.low.frequency.value = 80;
            eqNodes.low.gain.value = 2;

            // 2. Low-Mid: 250Hz Peaking
            eqNodes.lowMid = audioCtx.createBiquadFilter();
            eqNodes.lowMid.type = 'peaking';
            eqNodes.lowMid.frequency.value = 250;
            eqNodes.lowMid.Q.value = 1.0;
            eqNodes.lowMid.gain.value = 1;

            // 3. Mid: 1000Hz Peaking
            eqNodes.mid = audioCtx.createBiquadFilter();
            eqNodes.mid.type = 'peaking';
            eqNodes.mid.frequency.value = 1000;
            eqNodes.mid.Q.value = 1.0;
            eqNodes.mid.gain.value = 3;

            // 4. High-Mid: 4000Hz Peaking
            eqNodes.highMid = audioCtx.createBiquadFilter();
            eqNodes.highMid.type = 'peaking';
            eqNodes.highMid.frequency.value = 4000;
            eqNodes.highMid.Q.value = 1.0;
            eqNodes.highMid.gain.value = 2;

            // 5. High: 12000Hz Highshelf
            eqNodes.high = audioCtx.createBiquadFilter();
            eqNodes.high.type = 'highshelf';
            eqNodes.high.frequency.value = 12000;
            eqNodes.high.gain.value = 1;

            // Conexão em cascata serial
            mediaSourceNode.connect(eqNodes.low);
            eqNodes.low.connect(eqNodes.lowMid);
            eqNodes.lowMid.connect(eqNodes.mid);
            eqNodes.mid.connect(eqNodes.highMid);
            eqNodes.highMid.connect(eqNodes.high);
            eqNodes.high.connect(audioCtx.destination);
        }
    } catch (e) {
        console.warn('[WeazelRadio] Web Audio API fallback to direct audio:', e);
    }
}

function applyEqualizer(presetOrValues) {
    if (!eqNodes.low) return;

    let values = EQ_PRESETS.flat;
    if (typeof presetOrValues === 'string' && EQ_PRESETS[presetOrValues]) {
        values = EQ_PRESETS[presetOrValues];
    } else if (typeof presetOrValues === 'object') {
        values = presetOrValues;
    }

    if (values.low !== undefined) eqNodes.low.gain.value = Math.max(-40, Math.min(40, values.low));
    if (values.lowMid !== undefined) eqNodes.lowMid.gain.value = Math.max(-40, Math.min(40, values.lowMid));
    if (values.mid !== undefined) eqNodes.mid.gain.value = Math.max(-40, Math.min(40, values.mid));
    if (values.highMid !== undefined) eqNodes.highMid.gain.value = Math.max(-40, Math.min(40, values.highMid));
    if (values.high !== undefined) eqNodes.high.gain.value = Math.max(-40, Math.min(40, values.high));
}

// Extrai ID do vídeo do YouTube de qualquer formato de URL
function extractYouTubeId(url) {
    if (!url) return null;
    const cleanUrl = url.trim();
    if (/^[a-zA-Z0-9_-]{11}$/.test(cleanUrl)) return cleanUrl;
    const match = cleanUrl.match(/(?:youtu\.be\/|(?:www\.|music\.)?youtube\.com\/(?:embed\/|v\/|shorts\/|watch\?v=|watch\?.+&v=))([\w-]{11})/i);
    return match ? match[1] : null;
}

// Extrai ID de Playlist do YouTube (parâmetro list=...)
function extractYouTubePlaylistId(url) {
    if (!url) return null;
    const match = url.trim().match(/[?&]list=([a-zA-Z0-9_-]+)/i);
    return match ? match[1] : null;
}

let pendingPlay = null;

function initYouTubePlayer() {
    if (ytPlayer || !window.YT || !window.YT.Player) return;
    try {
        ytPlayer = new YT.Player('ytplayer', {
            host: 'https://www.youtube-nocookie.com',
            height: '10',
            width: '10',
            playerVars: {
                autoplay: 0,
                controls: 0,
                disablekb: 1,
                fs: 0,
                rel: 0,
                playsinline: 1
            },
            events: {
                onReady: () => {
                    ytReady = true;
                    console.log('[WeazelRadio] YouTube IFrame API Ready!');
                    if (pendingPlay) {
                        const p = pendingPlay;
                        pendingPlay = null;
                        playTrack(p.url, p.startTime, p.volume);
                    }
                },
                onStateChange: (event) => {
                    if (event.data === YT.PlayerState.ENDED) {
                        if (ytPlayer && ytPlayer.getPlaylist && ytPlayer.getPlaylistIndex) {
                            const list = ytPlayer.getPlaylist();
                            const idx = ytPlayer.getPlaylistIndex();
                            if (list && idx !== -1 && idx < list.length - 1) {
                                return;
                            }
                        }
                        notifyTrackEnded();
                    }
                },
                onError: (err) => {
                    console.warn('[WeazelRadio] YouTube Player Error:', err);
                    notifyTrackEnded();
                }
            }
        });
    } catch (e) {
        console.warn('[WeazelRadio] Error initializing YT.Player:', e);
    }
}

// Callback oficial do YouTube IFrame API
window.onYouTubeIframeAPIReady = function() {
    initYouTubePlayer();
};

if (window.YT && window.YT.Player) {
    initYouTubePlayer();
}

function notifyTrackEnded() {
    fetch(`https://${resourceName}/radioTrackEnded`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
}

function updateCalculatedVolume() {
    const finalVol = Math.max(0, Math.min(1.0, currentVolume * attenuationFactor * streamerSafetyFactor));
    if (currentSourceType === 'youtube' && ytPlayer) {
        if (ytPlayer.unMute) {
            ytPlayer.unMute();
        }
        if (ytPlayer.setVolume) {
            ytPlayer.setVolume(Math.round(finalVol * 100));
        }
    } else if (currentSourceType === 'html5' && html5Audio) {
        html5Audio.volume = finalVol;
    }
}

function playTrack(url, startTime = 0, volume = 0.65) {
    if (!url) return;
    initWebAudio();
    stopTrack();

    baseVolume = volume;
    currentVolume = volume;
    const playlistId = extractYouTubePlaylistId(url);
    const ytId = extractYouTubeId(url);

    if (playlistId || ytId) {
        currentSourceType = 'youtube';
        const startSeconds = Math.max(0, Math.floor(startTime));

        const triggerPlay = () => {
            try {
                if (playlistId && ytPlayer.loadPlaylist) {
                    ytPlayer.loadPlaylist({
                        list: playlistId,
                        listType: 'playlist',
                        index: 0,
                        startSeconds: startSeconds
                    });
                } else if (ytId && ytPlayer.loadVideoById) {
                    ytPlayer.loadVideoById({
                        videoId: ytId,
                        startSeconds: startSeconds
                    });
                }
                updateCalculatedVolume();
                if (ytPlayer.unMute) {
                    ytPlayer.unMute();
                }
                if (ytPlayer.playVideo) {
                    ytPlayer.playVideo();
                }
            } catch (err) {
                console.warn('[WeazelRadio] Playback trigger error:', err);
            }
        };

        if (ytReady && ytPlayer && (ytPlayer.loadVideoById || ytPlayer.loadPlaylist)) {
            triggerPlay();
        } else {
            pendingPlay = { url, startTime, volume };
            if (!ytPlayer && window.YT && window.YT.Player) {
                initYouTubePlayer();
            }
            let attempts = 0;
            const interval = setInterval(() => {
                attempts++;
                if (ytReady && ytPlayer && (ytPlayer.loadVideoById || ytPlayer.loadPlaylist)) {
                    clearInterval(interval);
                    triggerPlay();
                } else if (attempts > 50) {
                    clearInterval(interval);
                }
            }, 100);
        }
    } else {
        currentSourceType = 'html5';
        if (html5Audio) {
            html5Audio.src = url;
            html5Audio.currentTime = Math.max(0, startTime);
            updateCalculatedVolume();
            html5Audio.play().catch((err) => {
                console.warn('[WeazelRadio] HTML5 Audio Playback error:', err);
            });
            html5Audio.onended = () => {
                notifyTrackEnded();
            };
        }
    }
}

function stopTrack() {
    if (ytPlayer && ytPlayer.stopVideo) {
        ytPlayer.stopVideo();
    }
    if (html5Audio) {
        html5Audio.pause();
        html5Audio.currentTime = 0;
        html5Audio.src = '';
    }
    currentSourceType = null;
}

// Receptor de Mensagens NUI do FiveM
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.resource) {
        resourceName = data.resource;
    }

    switch (data.action) {
        case 'playRadio':
            playTrack(data.url, data.startTime || 0, data.volume !== undefined ? data.volume : 0.65);
            break;

        case 'stopRadio':
            stopTrack();
            break;

        case 'pauseRadio':
            if (currentSourceType === 'youtube' && ytPlayer && ytPlayer.pauseVideo) {
                ytPlayer.pauseVideo();
            } else if (currentSourceType === 'html5' && html5Audio) {
                html5Audio.pause();
            }
            break;

        case 'resumeRadio':
            if (currentSourceType === 'youtube' && ytPlayer && ytPlayer.playVideo) {
                ytPlayer.playVideo();
            } else if (currentSourceType === 'html5' && html5Audio) {
                html5Audio.play().catch(() => {});
            }
            break;

        case 'setVolume':
            if (data.volume !== undefined) {
                currentVolume = parseFloat(data.volume);
                updateCalculatedVolume();
            }
            break;

        case 'setEQ':
            applyEqualizer(data.preset || data.eq);
            break;

        case 'setSafetyPreference':
            // 'all' = 1.0, 'streamer' = 0.0 (DMCA Safe), 'muted' = 0.0
            if (data.mode === 'streamer' || data.mode === 'muted') {
                streamerSafetyFactor = 0.0;
            } else {
                streamerSafetyFactor = 1.0;
            }
            updateCalculatedVolume();
            break;

        case 'attenuate':
            // Plantão Urgente (Breaking News): Reduz o volume da música para 15%
            attenuationFactor = data.factor !== undefined ? parseFloat(data.factor) : 0.15;
            isAttenuated = true;
            updateCalculatedVolume();
            break;

        case 'restoreVolume':
            // Fim do Plantão Urgente: Retoma volume normal
            attenuationFactor = 1.0;
            isAttenuated = false;
            updateCalculatedVolume();
            break;
    }
});
