/**
 * vp_newspaper — Frontend Script (Clean, Unobfuscated & Hardened)
 * Suporte a Leitor, Editor WYSIWYG e Painel de Gestão da Weazel News
 */

(function () {
    'use strict';

    // ─── HELPER NUI FETCH ──────────────────────────────────────────
    function nuiFetch(endpoint, data = {}) {
        const resName = window.GetParentResourceName ? window.GetParentResourceName() : 'vp_newspaper';
        return fetch(`https://${resName}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        }).catch(err => {
            console.warn('[vp_newspaper:NUI] Request failed:', endpoint, err);
        });
    }

    // ─── SANITIZAÇÃO E PREVENÇÃO DE XSS ───────────────────────────
    function escapeHtml(str) {
        if (!str) return '';
        const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
        return String(str).replace(/[&<>"']/g, m => map[m]);
    }

    function sanitizeImageUrl(url) {
        if (!url) return '';
        url = String(url).trim();
        // Permite apenas http, https ou imagens relativas válidas
        if (/^https?:\/\/[^\s$.?#].[^\s]*$/i.test(url) || /^[a-zA-Z0-9_\-\/]+\.(png|jpg|jpeg|webp)$/i.test(url)) {
            return url;
        }
        return '';
    }

    // ─── ESTADO LOCAL ──────────────────────────────────────────────
    let isEditorMode = false;
    let currentPage = 1;
    let maxPages = 5;
    let selectedElement = null;
    let elementsCounter = 0;
    let currentRevision = 1;
    let flipAudio = null;

    try {
        if (typeof Howl !== 'undefined') {
            flipAudio = new Howl({ src: ['swap.ogg'], volume: 0.25 });
        }
    } catch (e) {
        console.warn('[vp_newspaper] Audio fallback:', e);
    }

    // ─── INICIALIZAÇÃO DE EVENTOS DE INTERFACE ──────────────────────
    $(document).ready(function () {
        setupEditorControls();
        setupManagementControls();
        setupKeyboardShortcuts();
    });

    // ─── MENSAGENS RECEBIDAS DO CLIENT FIVE M ──────────────────────
    window.addEventListener('message', function (event) {
        const item = event.data;
        if (!item || !item.type) return;

        switch (item.type) {
            case 'locales':
                applyLocales(item.texts);
                break;

            case 'open':
                // Abre em modo Editor (WYSIWYG)
                isEditorMode = true;
                currentPage = 1;
                currentRevision = item.revision || 1;
                if (item.general && item.general.allowedMaxPage) {
                    maxPages = item.general.allowedMaxPage;
                }
                $('.annneeen, .container31, #readerToolbar').removeClass('active').hide();
                $('.container, .controlPage, .page').addClass('active').show();
                renderPageContent(item.texts);
                updatePaginationDisplay();
                break;

            case 'openView':
                // Abre em modo Leitor (Somente visualização)
                isEditorMode = false;
                currentPage = 1;
                if (item.general && item.general.allowedMaxPage) {
                    maxPages = item.general.allowedMaxPage;
                }
                $('.annneeen, .container31, .controlPage').removeClass('active').hide();
                $('.container, .page, #readerToolbar').addClass('active').show();
                renderPageContent(item.texts);
                updatePaginationDisplay();
                break;

            case 'exit':
            case 'close':
                // Fecha qualquer interface aberta
                $('.container, .controlPage, .annneeen, .container31, #readerToolbar').removeClass('active').hide();
                $('.page').empty();
                selectElement(null);
                isEditorMode = false;
                break;

            case 'changePage':
                currentRevision = item.revision || currentRevision;
                renderPageContent(item.texts);
                updatePaginationDisplay();
                if (flipAudio) flipAudio.play();
                break;

            case 'changePageView':
                renderPageContent(item.texts);
                updatePaginationDisplay();
                if (flipAudio) flipAudio.play();
                break;

            case 'playSound':
                if (flipAudio) flipAudio.play();
                break;

            case 'updateRevision':
                currentRevision = item.revision || (currentRevision + 1);
                break;

            case 'manager':
                // Abre Painel de Gestão da Empresa
                $('.container, .controlPage').removeClass('active').hide();
                $('.annneeen, .container31').addClass('active').show();
                renderManagementDashboard(item.data);
                break;
        }
    });

    // ─── TEMA E ESTILO DA FOLHA (JORNAL VS REVISTA) ───────────────
    function setPageTheme(theme, customBg) {
        const $page = $('.page');
        $page.removeClass('theme-newspaper theme-magazine-clean theme-magazine-dark theme-vintage');

        theme = theme || 'newspaper';
        $page.addClass(`theme-${theme}`);
        $page.attr('data-theme', theme);

        if (customBg) {
            $page.css({
                'background-color': customBg,
                'background-image': 'none'
            });
            $page.attr('data-custom-bg', customBg);
            $('#pageCustomBg').val(customBg);
        } else {
            $page.css({
                'background-color': '',
                'background-image': ''
            });
            $page.removeAttr('data-custom-bg');
        }

        $('.btn-theme').removeClass('active');
        $(`.btn-theme[data-theme="${theme}"]`).addClass('active');
    }

    // ─── RENDERIZADOR DE ELEMENTOS DA PÁGINA ───────────────────────
    function renderPageContent(elements) {
        const $page = $('.page');
        $page.empty();
        selectedElement = null;
        updateSelectedElementControls();
        setPageTheme('newspaper', '');

        if (typeof elements === 'string') {
            try {
                elements = JSON.parse(elements);
            } catch (e) {
                elements = [];
            }
        }

        if (elements && typeof elements === 'object' && !Array.isArray(elements)) {
            elements = Object.values(elements);
        }

        if (!Array.isArray(elements)) elements = [];

        elements.forEach(item => {
            if (!item || !item.type) return;

            // Metadados de tema e folha
            if (item.type === '_pageMeta') {
                setPageTheme(item.theme || 'newspaper', item.bgColor || '');
                return;
            }

            elementsCounter = Math.max(elementsCounter, (parseInt(item.id, 10) || 0) + 1);
            let $el;

            if (item.type === 'text') {
                $el = $('<div class="draggable"></div>');
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'text');
                $el.text(item.content || item.text || 'Texto');

                if (item.fontFamily) $el.css('font-family', item.fontFamily);
                if (item.fontSize) $el.css('font-size', item.fontSize);
                if (item.color) $el.css('color', item.color);
                if (item.opacity) $el.css('opacity', item.opacity);
                if (item.letterSpacing) $el.css('letter-spacing', item.letterSpacing);
                if (item.fontWeight) $el.css('font-weight', item.fontWeight);
                if (item.textAlign) $el.css('text-align', item.textAlign);
                if (item.fontStyle) $el.css('font-style', item.fontStyle);
                if (item.textDecoration) $el.css('text-decoration', item.textDecoration);
                if (item.textTransform) $el.css('text-transform', item.textTransform);
                if (item.backgroundColor) {
                    $el.css({
                        'background-color': item.backgroundColor,
                        'padding': item.padding || '3px 8px',
                        'border-radius': '3px'
                    });
                }
                if (item.width) $el.css('width', item.width);

            } else if (item.type === 'image') {
                const safeUrl = sanitizeImageUrl(item.src || item.url);
                if (!safeUrl) return;

                $el = $('<div class="draggable"><img style="width:100%; height:100%; object-fit:cover; pointer-events:none; border-radius:inherit;" /></div>');
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'image');
                $el.find('img').attr('src', safeUrl);

                if (item.width) $el.css('width', item.width);
                if (item.height) $el.css('height', item.height);
                if (item.opacity) $el.css('opacity', item.opacity);
                if (item.borderRadius) $el.css('border-radius', item.borderRadius);
                if (item.border) $el.css('border', item.border);

            } else if (item.type === 'line') {
                const orient = item.orientation || 'horizontal';
                $el = $(`<div class="draggable newspaper-line ${orient}"></div>`);
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'line');
                $el.attr('data-orientation', orient);

                if (item.width) $el.css('width', item.width);
                if (item.height) $el.css('height', item.height);
                if (item.backgroundColor) $el.css('background-color', item.backgroundColor);
                if (item.opacity) $el.css('opacity', item.opacity);

            } else if (item.type === 'box') {
                $el = $('<div class="draggable newspaper-box"></div>');
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'box');

                if (item.width) $el.css('width', item.width);
                if (item.height) $el.css('height', item.height);
                if (item.backgroundColor) $el.css('background-color', item.backgroundColor);
                if (item.borderColor) $el.css('border-color', item.borderColor);
                if (item.borderWidth) $el.css('border-width', item.borderWidth);
                if (item.opacity) $el.css('opacity', item.opacity);

            } else if (item.type === 'badge') {
                const bClass = item.badgeClass || 'badge-urgente';
                $el = $(`<div class="draggable newspaper-badge ${bClass}">${escapeHtml(item.badgeText || 'URGENTE')}</div>`);
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'badge');
                $el.attr('data-badge', item.badgeText || 'URGENTE');

                if (item.color) $el.css('color', item.color);
                if (item.backgroundColor) $el.css('background-color', item.backgroundColor);
                if (item.opacity) $el.css('opacity', item.opacity);
            }

            if ($el) {
                $el.css({
                    top: item.top || '10px',
                    left: item.left || '10px',
                    position: 'absolute',
                    zIndex: item.zIndex || 1
                });

                if (item.transform) {
                    $el.css('transform', item.transform);
                }

                if (isEditorMode) {
                    $el.attr('contenteditable', (item.type === 'text' || item.type === 'badge') ? 'true' : 'false');
                    attachDraggable($el);
                    attachResizable($el, item.type);
                } else {
                    $el.attr('contenteditable', 'false');
                }

                $page.append($el);
            }
        });
    }

    function attachDraggable($el) {
        if (typeof $el.draggable === 'function') {
            $el.draggable({
                containment: '.page',
                stop: function () {
                    selectElement($(this));
                }
            });
        }

        $el.off('click').on('click', function (e) {
            e.stopPropagation();
            if (isEditorMode) {
                selectElement($(this));
            }
        });
    }

    function attachResizable($el, type) {
        if (typeof $el.resizable !== 'function') return;

        let handles = 'n, e, s, w, ne, se, sw, nw';
        if (type === 'line') {
            const isHoriz = $el.hasClass('horizontal');
            handles = isHoriz ? 'e, w' : 'n, s';
        }

        $el.resizable({
            containment: '.page',
            handles: handles,
            stop: function (event, ui) {
                selectElement($(this));
                if (selectedElement && selectedElement.attr('data-type') === 'image') {
                    $('#imageWidth').val(Math.round(ui.size.width));
                    $('#imageHeight').val(Math.round(ui.size.height));
                }
            }
        });
    }

    function selectElement($el) {
        $('.draggable').removeClass('selected');
        selectedElement = $el;
        if (selectedElement) {
            selectedElement.addClass('selected');
        }
        updateSelectedElementControls();
    }

    // Helper para extrair o ângulo de rotação de um transform CSS
    function getRotationDegrees($el) {
        const tr = $el.css('transform');
        if (!tr || tr === 'none') return 0;
        const values = tr.split('(')[1].split(')')[0].split(',');
        const a = parseFloat(values[0]);
        const b = parseFloat(values[1]);
        const radians = Math.atan2(b, a);
        let angle = Math.round(radians * (180 / Math.PI));
        return angle;
    }

    function updateSelectedElementControls() {
        const hasSelection = selectedElement !== null;
        $('#deleteButton, #duplicateButton, #layerUp, #layerDown').prop('disabled', !hasSelection);
        $('#elementRotate, #btnResetRotate, #elementOpactiy').prop('disabled', !hasSelection);
        $('#textLeft, #textCenter, #textRight, #textJustify').prop('disabled', !hasSelection);
        $('#btnBold, #btnItalic, #btnUnderline, #btnUppercase').prop('disabled', !hasSelection);

        if (!hasSelection) {
            $('#elementRotate').val(0);
            $('#rotateValue').text('0°');
            $('#elementOpactiy').val(10);
            $('#opacityValue').text('100%');
            return;
        }

        // Rotação e Opacidade
        const rot = getRotationDegrees(selectedElement);
        $('#elementRotate').val(rot);
        $('#rotateValue').text(`${rot}°`);

        const op = Math.round((parseFloat(selectedElement.css('opacity')) || 1) * 10);
        $('#elementOpactiy').val(op);
        $('#opacityValue').text(`${op * 10}%`);

        const elType = selectedElement.attr('data-type');

        // Se for texto
        if (elType === 'text') {
            const fs = parseInt(selectedElement.css('font-size'), 10) || 18;
            $('#sizeInput').val(fs);

            const fw = parseInt(selectedElement.css('font-weight'), 10) || 400;
            $('#btnBold').toggleClass('active', fw >= 700);

            const fStyle = selectedElement.css('font-style');
            $('#btnItalic').toggleClass('active', fStyle === 'italic');

            const tDec = selectedElement.css('text-decoration');
            $('#btnUnderline').toggleClass('active', tDec && tDec.includes('underline'));

            const tTrans = selectedElement.css('text-transform');
            $('#btnUppercase').toggleClass('active', tTrans === 'uppercase');

            const lSpace = parseInt(selectedElement.css('letter-spacing'), 10) || 0;
            $('#textSpace').val(lSpace);
        }

        // Se for imagem
        if (elType === 'image') {
            $('#imageWidth').val(Math.round(selectedElement.width()));
            $('#imageHeight').val(Math.round(selectedElement.height()));
        }

        // Se for box
        if (elType === 'box') {
            const bg = selectedElement.css('background-color');
            if (bg) $('#boxBgColor').val(rgbToHex(bg));
            const bc = selectedElement.css('border-color');
            if (bc) $('#boxBorderColor').val(rgbToHex(bc));
        }
    }

    function rgbToHex(rgb) {
        if (!rgb || rgb.indexOf('rgb') === -1) return '#ffffff';
        const parts = rgb.match(/\d+/g);
        if (!parts || parts.length < 3) return '#ffffff';
        return "#" + ((1 << 24) + (parseInt(parts[0]) << 16) + (parseInt(parts[1]) << 8) + parseInt(parts[2])).toString(16).slice(1);
    }

    // ─── CONFIGURAÇÃO DE CONTROLES DO EDITOR ───────────────────────
    function setupEditorControls() {
        // Alternância de Abas Superiores do Editor
        $('.editor-tab-btn').on('click', function () {
            const tab = $(this).attr('data-tab');
            if (!tab) return;
            $('.editor-tab-btn').removeClass('active');
            $(this).addClass('active');
            $('.editor-tab-content').removeClass('active').hide();
            $(`#${tab}`).addClass('active').show();
        });

        // Deseleciona ao clicar no fundo da página
        $('.page').on('click', function () {
            selectElement(null);
        });

        // Paginação
        $('#previousPage').on('click', function () {
            if (currentPage > 1) {
                currentPage--;
                nuiFetch('changePage', { page: currentPage });
            }
        });

        $('#nextPage').on('click', function () {
            if (currentPage < maxPages) {
                currentPage++;
                nuiFetch('changePage', { page: currentPage });
            }
        });

        $('#readerPrevPage').on('click', function () {
            if (currentPage > 1) {
                currentPage--;
                nuiFetch('changePage', { page: currentPage });
            }
        });

        $('#readerNextPage').on('click', function () {
            if (currentPage < maxPages) {
                currentPage++;
                nuiFetch('changePage', { page: currentPage });
            }
        });

        $('#readerCloseBtn, #editorCloseBtn').on('click', function () {
            closeUI();
        });

        // Inserir Texto Livre
        $('#addText').on('click', function () {
            elementsCounter++;
            const $el = $('<div class="draggable" contenteditable="true">Novo Texto</div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'text');
            $el.css({
                top: '60px',
                left: '60px',
                position: 'absolute',
                fontSize: '18px',
                color: '#111111',
                fontFamily: 'Montserrat',
                zIndex: 10
            });

            attachDraggable($el);
            attachResizable($el, 'text');
            $('.page').append($el);
            selectElement($el);
        });

        // Modelos Rápidos de Texto (Presets)
        $('.btn-preset').on('click', function () {
            const preset = $(this).attr('data-preset');
            elementsCounter++;
            let $el;

            if (preset === 'headline') {
                $el = $('<div class="draggable" contenteditable="true">MANCHETE PRINCIPAL</div>');
                $el.css({
                    fontSize: '32px',
                    fontWeight: '800',
                    fontFamily: 'Playfair Display',
                    color: '#111111',
                    textAlign: 'center',
                    width: '580px',
                    top: '40px',
                    left: '60px'
                });
            } else if (preset === 'subheadline') {
                $el = $('<div class="draggable" contenteditable="true">Subtítulo explicativo com detalhes da reportagem</div>');
                $el.css({
                    fontSize: '18px',
                    fontWeight: '600',
                    fontFamily: 'Montserrat',
                    color: '#374151',
                    textAlign: 'center',
                    width: '560px',
                    top: '95px',
                    left: '70px'
                });
            } else if (preset === 'body') {
                $el = $('<div class="draggable" contenteditable="true">Escreva aqui a sua coluna de notícias detalhada. O jornalismo de Los Santos traz os fatos com precisão e verdade.</div>');
                $el.css({
                    fontSize: '13px',
                    fontWeight: '400',
                    fontFamily: 'Merriweather',
                    color: '#111111',
                    textAlign: 'left',
                    width: '320px',
                    lineHeight: '1.4',
                    top: '150px',
                    left: '50px'
                });
            } else if (preset === 'quote') {
                $el = $('<div class="draggable" contenteditable="true">"A verdade é o primeiro dever de quem informa."</div>');
                $el.css({
                    fontSize: '16px',
                    fontStyle: 'italic',
                    fontFamily: 'Georgia',
                    color: '#1e3a8a',
                    backgroundColor: 'rgba(30, 58, 138, 0.08)',
                    padding: '8px 12px',
                    borderLeft: '4px solid #1e3a8a',
                    borderRadius: '2px',
                    width: '400px',
                    top: '200px',
                    left: '100px'
                });
            }

            if ($el) {
                $el.attr('data-id', elementsCounter);
                $el.attr('data-type', 'text');
                $el.css({ position: 'absolute', zIndex: 12 });
                attachDraggable($el);
                attachResizable($el, 'text');
                $('.page').append($el);
                selectElement($el);
            }
        });

        // Botoeiras de Formatação de Texto (B, I, U, TT)
        $('#btnBold').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const currentWeight = parseInt(selectedElement.css('font-weight'), 10) || 400;
                const newWeight = currentWeight >= 700 ? '400' : '800';
                selectedElement.css('font-weight', newWeight);
                $(this).toggleClass('active', newWeight === '800');
            }
        });

        $('#btnItalic').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const currentStyle = selectedElement.css('font-style');
                const newStyle = currentStyle === 'italic' ? 'normal' : 'italic';
                selectedElement.css('font-style', newStyle);
                $(this).toggleClass('active', newStyle === 'italic');
            }
        });

        $('#btnUnderline').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const currentDec = selectedElement.css('text-decoration');
                const isUnder = currentDec && currentDec.includes('underline');
                selectedElement.css('text-decoration', isUnder ? 'none' : 'underline');
                $(this).toggleClass('active', !isUnder);
            }
        });

        $('#btnUppercase').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const currentTrans = selectedElement.css('text-transform');
                const isUpper = currentTrans === 'uppercase';
                selectedElement.css('text-transform', isUpper ? 'none' : 'uppercase');
                $(this).toggleClass('active', !isUpper);
            }
        });

        // Alinhamento
        $('#textLeft').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'left');
        });
        $('#textCenter').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'center');
        });
        $('#textRight').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'right');
        });
        $('#textJustify').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'justify');
        });

        // Tamanho de Fonte
        $('#sizeInput').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const sz = parseInt($(this).val(), 10) || 16;
                selectedElement.css('font-size', `${sz}px`);
            }
        });

        // Cor do Texto
        $('#colorPicker').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                selectedElement.css('color', $(this).val());
            }
        });

        // Cor de Fundo do Texto / Tarja
        $('#textBgColor').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                selectedElement.css({
                    'background-color': $(this).val(),
                    'padding': '3px 8px',
                    'border-radius': '3px'
                });
            }
        });

        $('#btnTextBgNone').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                selectedElement.css({
                    'background-color': 'transparent',
                    'padding': ''
                });
            }
        });

        // Espaçamento de Letras
        $('#textSpace').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const sp = parseInt($(this).val(), 10) || 0;
                selectedElement.css('letter-spacing', `${sp}px`);
            }
        });

        // Dropdown de Fontes
        $('#fontPicker .selected333').on('click', function (e) {
            e.stopPropagation();
            $('#fontPicker .dropdown-list').toggle();
        });

        $('#fontPicker .dropdown-list li').on('click', function () {
            const font = $(this).attr('data-font');
            if (selectedElement && font) {
                selectedElement.css('font-family', font);
            }
            $('#fontPicker .dropdown-list').hide();
        });

        $(document).on('click', function () {
            $('#fontPicker .dropdown-list').hide();
        });

        // Inserir Imagem
        $('#addImage').on('click', function () {
            const rawUrl = $('#imageInput').val();
            const safeUrl = sanitizeImageUrl(rawUrl);

            if (!safeUrl) {
                nuiFetch('notify', { notify: 'enterImageURL' });
                return;
            }

            const w = parseInt($('#imageWidth').val(), 10) || 300;
            const h = parseInt($('#imageHeight').val(), 10) || 200;

            elementsCounter++;
            const $el = $('<div class="draggable"><img style="width:100%; height:100%; object-fit:cover; pointer-events:none; border-radius:inherit;" /></div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'image');
            $el.find('img').attr('src', safeUrl);
            $el.css({
                top: '80px',
                left: '60px',
                width: `${w}px`,
                height: `${h}px`,
                position: 'absolute',
                zIndex: 5
            });

            attachDraggable($el);
            attachResizable($el, 'image');
            $('.page').append($el);
            selectElement($el);
            $('#imageInput').val('');
        });

        // Ajustes de Cantos da Foto
        $('.btn-opt[data-radius]').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'image') {
                const rad = $(this).attr('data-radius');
                selectedElement.css('border-radius', rad);
                $('.btn-opt[data-radius]').removeClass('active');
                $(this).addClass('active');
            }
        });

        // Moldura da Foto
        $('.btn-opt[data-border]').on('click', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'image') {
                const bdr = $(this).attr('data-border');
                selectedElement.css('border', bdr);
                if (bdr.includes('5px')) {
                    selectedElement.css('box-shadow', '0 6px 15px rgba(0,0,0,0.3)');
                } else {
                    selectedElement.css('box-shadow', 'none');
                }
                $('.btn-opt[data-border]').removeClass('active');
                $(this).addClass('active');
            }
        });

        // Inserir Linha Horizontal
        $('#addHLine').on('click', function () {
            elementsCounter++;
            const $el = $('<div class="draggable newspaper-line horizontal"></div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'line');
            $el.attr('data-orientation', 'horizontal');
            $el.css({
                top: '120px',
                left: '60px',
                width: '300px',
                height: '2px',
                backgroundColor: '#111111',
                position: 'absolute',
                zIndex: 8
            });

            attachDraggable($el);
            attachResizable($el, 'line');
            $('.page').append($el);
            selectElement($el);
        });

        // Inserir Linha Vertical
        $('#addVLine').on('click', function () {
            elementsCounter++;
            const $el = $('<div class="draggable newspaper-line vertical"></div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'line');
            $el.attr('data-orientation', 'vertical');
            $el.css({
                top: '120px',
                left: '200px',
                width: '2px',
                height: '250px',
                backgroundColor: '#111111',
                position: 'absolute',
                zIndex: 8
            });

            attachDraggable($el);
            attachResizable($el, 'line');
            $('.page').append($el);
            selectElement($el);
        });

        // Inserir Caixa de Destaque
        $('#addBox').on('click', function () {
            elementsCounter++;
            const $el = $('<div class="draggable newspaper-box"></div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'box');
            $el.css({
                top: '100px',
                left: '60px',
                width: '240px',
                height: '140px',
                backgroundColor: $('#boxBgColor').val() || '#ffffff',
                borderColor: $('#boxBorderColor').val() || '#111111',
                borderWidth: '1.5px',
                position: 'absolute',
                zIndex: 4
            });

            attachDraggable($el);
            attachResizable($el, 'box');
            $('.page').append($el);
            selectElement($el);
        });

        $('#boxBgColor').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'box') {
                selectedElement.css('background-color', $(this).val());
            }
        });

        $('#boxBorderColor').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'box') {
                selectedElement.css('border-color', $(this).val());
            }
        });

        // Selos Editoriais
        $('.btn-badge').on('click', function () {
            const badgeType = $(this).attr('data-badge') || 'URGENTE';
            let bClass = 'badge-urgente';
            if (badgeType === 'EXCLUSIVO') bClass = 'badge-exclusivo';
            if (badgeType === 'POLICIAL') bClass = 'badge-policial';
            if (badgeType === 'PLANTÃO') bClass = 'badge-plantao';
            if (badgeType === 'OPINIÃO') bClass = 'badge-opiniao';
            if (badgeType === 'CLASSIFICADOS') bClass = 'badge-classificados';

            elementsCounter++;
            const $el = $(`<div class="draggable newspaper-badge ${bClass}" contenteditable="true">${badgeType}</div>`);
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'badge');
            $el.attr('data-badge', badgeType);
            $el.css({
                top: '50px',
                left: '60px',
                position: 'absolute',
                zIndex: 20
            });

            attachDraggable($el);
            attachResizable($el, 'badge');
            $('.page').append($el);
            selectElement($el);
        });

        // Temas de Folha (Jornal vs Revista)
        $('.btn-theme').on('click', function () {
            const theme = $(this).attr('data-theme') || 'newspaper';
            setPageTheme(theme, '');
        });

        $('#pageCustomBg').on('input', function () {
            const color = $(this).val();
            const currentTheme = $('.page').attr('data-theme') || 'newspaper';
            setPageTheme(currentTheme, color);
        });

        $('#btnResetPageBg').on('click', function () {
            setPageTheme('newspaper', '');
        });

        // Camadas (Z-Index)
        $('#layerUp').on('click', function () {
            if (selectedElement) {
                const currentZ = parseInt(selectedElement.css('z-index'), 10) || 1;
                selectedElement.css('z-index', currentZ + 1);
            }
        });

        $('#layerDown').on('click', function () {
            if (selectedElement) {
                const currentZ = parseInt(selectedElement.css('z-index'), 10) || 1;
                selectedElement.css('z-index', Math.max(1, currentZ - 1));
            }
        });

        // Duplicar Elemento
        $('#duplicateButton').on('click', function () {
            if (!selectedElement) return;

            elementsCounter++;
            const $clone = selectedElement.clone();
            $clone.attr('data-id', elementsCounter);
            $clone.removeClass('selected');
            $clone.find('.ui-resizable-handle').remove(); // Remove handles antigos antes de clonar

            const curTop = parseInt(selectedElement.css('top'), 10) || 50;
            const curLeft = parseInt(selectedElement.css('left'), 10) || 50;
            $clone.css({
                top: `${curTop + 20}px`,
                left: `${curLeft + 20}px`
            });

            const elType = selectedElement.attr('data-type');
            if (elType === 'text' || elType === 'badge') {
                $clone.attr('contenteditable', 'true');
            }

            attachDraggable($clone);
            attachResizable($clone, elType);
            $('.page').append($clone);
            selectElement($clone);
        });

        // Rotação
        $('#elementRotate').on('input', function () {
            if (selectedElement) {
                const deg = parseInt($(this).val(), 10) || 0;
                selectedElement.css('transform', `rotate(${deg}deg)`);
                $('#rotateValue').text(`${deg}°`);
            }
        });

        $('#btnResetRotate').on('click', function () {
            if (selectedElement) {
                selectedElement.css('transform', 'rotate(0deg)');
                $('#elementRotate').val(0);
                $('#rotateValue').text('0°');
            }
        });

        // Opacidade
        $('#elementOpactiy').on('input', function () {
            if (selectedElement) {
                const op = (parseInt($(this).val(), 10) || 10) / 10;
                selectedElement.css('opacity', op);
                $('#opacityValue').text(`${Math.round(op * 100)}%`);
            }
        });

        // Deletar elemento selecionado
        $('#deleteButton').on('click', function () {
            if (selectedElement) {
                const id = selectedElement.attr('data-id');
                selectedElement.remove();
                selectedElement = null;
                updateSelectedElementControls();
                nuiFetch('deleteElement', { id: id, page: currentPage });
            }
        });

        // Limpar página inteira
        $('#clearPageButton').on('click', function () {
            $('.page').empty();
            selectedElement = null;
            updateSelectedElementControls();
            setPageTheme('newspaper', '');
            nuiFetch('clearPage', { page: currentPage });
        });

        // Salvar página no servidor (com OCC)
        $('#saveButton').on('click', function () {
            const elements = serializePage();
            nuiFetch('savePage', {
                cb: elements,
                page: currentPage,
                revision: currentRevision
            });

            const $btn = $(this);
            const originalHtml = $btn.html();
            $btn.html('<i class="fas fa-check"></i> Salvo!').css('background', '#15803d');
            setTimeout(function () {
                $btn.html(originalHtml).css('background', '');
            }, 1800);
        });
    }

    function serializePage() {
        const elements = [];

        // Salva metadados de folha
        const currentTheme = $('.page').attr('data-theme') || 'newspaper';
        const currentBg = $('.page').attr('data-custom-bg') || '';
        elements.push({
            type: '_pageMeta',
            theme: currentTheme,
            bgColor: currentBg
        });

        $('.page .draggable').each(function () {
            const $this = $(this);
            const type = $this.attr('data-type') || 'text';
            const id = $this.attr('data-id');

            const item = {
                id: id,
                type: type,
                top: $this.css('top'),
                left: $this.css('left'),
                opacity: $this.css('opacity'),
                zIndex: parseInt($this.css('z-index'), 10) || 1,
                transform: $this.css('transform') !== 'none' ? $this.css('transform') : ''
            };

            if (type === 'text') {
                item.text = $this.text();
                item.fontSize = $this.css('font-size');
                item.color = $this.css('color');
                item.fontFamily = $this.css('font-family');
                item.fontWeight = $this.css('font-weight');
                item.letterSpacing = $this.css('letter-spacing');
                item.textAlign = $this.css('text-align');
                item.fontStyle = $this.css('font-style');
                item.textDecoration = $this.css('text-decoration');
                item.textTransform = $this.css('text-transform');
                const bg = $this.css('background-color');
                if (bg && bg !== 'transparent' && bg !== 'rgba(0, 0, 0, 0)') {
                    item.backgroundColor = bg;
                    item.padding = $this.css('padding');
                }
                item.width = $this.css('width');

            } else if (type === 'image') {
                item.src = sanitizeImageUrl($this.find('img').attr('src'));
                item.width = $this.css('width');
                item.height = $this.css('height');
                item.borderRadius = $this.css('border-radius');
                item.border = $this.css('border');

            } else if (type === 'line') {
                item.orientation = $this.attr('data-orientation') || ($this.hasClass('horizontal') ? 'horizontal' : 'vertical');
                item.width = $this.css('width');
                item.height = $this.css('height');
                item.backgroundColor = $this.css('background-color');

            } else if (type === 'box') {
                item.width = $this.css('width');
                item.height = $this.css('height');
                item.backgroundColor = $this.css('background-color');
                item.borderColor = $this.css('border-color');
                item.borderWidth = $this.css('border-width');

            } else if (type === 'badge') {
                item.badgeText = $this.text();
                item.badgeClass = $this.attr('class').split(' ').filter(c => c.startsWith('badge-'))[0] || 'badge-urgente';
                item.color = $this.css('color');
                item.backgroundColor = $this.css('background-color');
            }

            elements.push(item);
        });

        return elements;
    }

    function updatePaginationDisplay() {
        $('#currentPageNumber').text(currentPage);
        $('#readerPageNumber').text(currentPage);
        $('#readerTotalPages').text(maxPages);
        $('#previousPage, #readerPrevPage').prop('disabled', currentPage <= 1);
        $('#nextPage, #readerNextPage').prop('disabled', currentPage >= maxPages);
    }

    // ─── CONFIGURAÇÃO DO PAINEL DE GESTÃO DA EMPRESA ───────────────
    function setupManagementControls() {
        // Alternância de Abas (Dashboard vs Funcionários)
        $('.nav-button').on('click', function () {
            const tab = $(this).attr('data-tab');
            if (!tab) return;

            if (tab === 'exit') {
                closeUI();
                return;
            }

            $('.nav-button').removeClass('active');
            $(this).addClass('active');

            $('.tab-content').removeClass('active').hide();
            $(`#${tab}`).addClass('active').show();
        });

        // Definir Preço do Jornal
        $('#setNewspaperPrice').on('click', function () {
            const price = parseInt($('#workerTaxAmount').val(), 10);
            if (!isNaN(price) && price > 0) {
                nuiFetch('databaseupdate', { type: 'newspaperPrice', amount: price });
                $('#workerTaxAmount').val('');
            }
        });

        // Depositar Fundos
        $('#addfunds').on('click', function () {
            const amount = parseInt($('#balanceamount').val(), 10);
            if (!isNaN(amount) && amount > 0) {
                nuiFetch('databaseupdate', { type: 'addFunds', amount: amount });
                $('#balanceamount').val('');
            }
        });

        // Sacar Fundos
        $('#withdrawfunds').on('click', function () {
            const amount = parseInt($('#balanceamount').val(), 10);
            if (!isNaN(amount) && amount > 0) {
                nuiFetch('databaseupdate', { type: 'withdrawFunds', amount: amount });
                $('#balanceamount').val('');
            }
        });

        // Contratar Funcionário
        $(document).on('click', '#hire_people', function () {
            const targetId = $(this).attr('data-id');
            if (targetId) {
                nuiFetch('iseal', { id: targetId });
            }
        });

        // Ações de Funcionário (Demitir, Promover, Rebaixar)
        $(document).on('click', '.worker-action', function () {
            const cid = $(this).attr('data-cid');
            const action = $(this).attr('data-action');
            if (cid && action) {
                nuiFetch('fireupdown', { id: cid, tip: action });
            }
        });
    }

    function renderManagementDashboard(data) {
        if (!data) return;

        // Saldo e Preço
        if (data.balance !== undefined) {
            $('#cashBalance').text(Number(data.balance).toLocaleString('en-US'));
        }
        if (data.newspaperPrice !== undefined) {
            $('#newspaperPrice').text(`$${Number(data.newspaperPrice).toLocaleString('en-US')}`);
        }

        // Transações (com escapeHtml completo)
        const $txList = $('#pastTransactions');
        $txList.empty();

        const txs = Array.isArray(data.transactions) ? data.transactions : [];
        txs.forEach(tx => {
            const isDeposit = tx.type === 'Deposit';
            const color = isDeposit ? 'rgba(100, 176, 108, 1)' : 'rgba(255, 60, 60, 1)';
            const prefix = isDeposit ? '+ $' : '- $';
            const label = escapeHtml(tx.type || 'Transação');
            const date = escapeHtml(tx.date || '');

            const $li = $(`
                <li>
                    <span>${prefix}${Number(tx.amount || 0).toLocaleString('en-US')} <small style="color:rgba(255,255,255,0.4); margin-left:8px;">${date}</small></span>
                    <span style="color: ${color};">${label}</span>
                </li>
            `);
            $txList.append($li);
        });

        // Funcionários Ativos
        const $workersList = $('#active_workers');
        $workersList.empty();

        const workers = Array.isArray(data.workers) ? data.workers : [];
        workers.forEach(w => {
            const name = escapeHtml(w.name || 'Desconhecido');
            const time = escapeHtml(w.time || 'Recente');
            const pos = escapeHtml(w.pos || 'Funcionário');
            const cid = escapeHtml(w.id || '');

            const $li = $(`
                <li style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
                    <div>
                        <span style="font-size: 16px; font-weight: bold; color: rgba(255, 255, 255, 0.9);">${name}</span>
                        <div style="font-size: 12px; color: rgba(255, 255, 255, 0.7);">
                            <span>Contratado em: ${time}</span><br>
                            <span>Cargo: ${pos}</span>
                        </div>
                    </div>
                    <div>
                        <button class="button worker-action" data-cid="${cid}" data-action="fire" style="margin-left: 5px; background-color: #b91c1c;">Demitir</button>
                        <button class="button worker-action" data-cid="${cid}" data-action="up" style="margin-left: 5px; background-color: #2563eb;">Promover</button>
                        <button class="button worker-action" data-cid="${cid}" data-action="down" style="margin-left: 5px; background-color: #4b5563;">Rebaixar</button>
                    </div>
                </li>
            `);
            $workersList.append($li);
        });
    }

    // ─── FECHAMENTO E TECLADO ──────────────────────────────────────
    function closeUI() {
        $('.container, .controlPage, .annneeen, .container31, #readerToolbar').removeClass('active').hide();
        $('.page').empty();
        selectElement(null);

        if (isEditorMode) {
            nuiFetch('exit2');
            isEditorMode = false;
        } else {
            nuiFetch('exit');
        }
    }

    function setupKeyboardShortcuts() {
        $(document).on('keydown', function (e) {
            // Tecla ESC (27)
            if (e.which === 27) {
                closeUI();
                return;
            }

            // Verifica se o foco está em um campo editável ou input
            const activeTag = document.activeElement ? document.activeElement.tagName.toLowerCase() : '';
            const isEditing = activeTag === 'input' || activeTag === 'textarea' || (document.activeElement && document.activeElement.isContentEditable);

            // Atalhos quando NÃO estiver digitando em campo de texto
            if (!isEditing && selectedElement) {
                const step = e.shiftKey ? 5 : 1;
                const curTop = parseInt(selectedElement.css('top'), 10) || 0;
                const curLeft = parseInt(selectedElement.css('left'), 10) || 0;

                // Seta Esquerda (37)
                if (e.which === 37) {
                    e.preventDefault();
                    selectedElement.css('left', `${curLeft - step}px`);
                }
                // Seta Cima (38)
                else if (e.which === 38) {
                    e.preventDefault();
                    selectedElement.css('top', `${curTop - step}px`);
                }
                // Seta Direita (39)
                else if (e.which === 39) {
                    e.preventDefault();
                    selectedElement.css('left', `${curLeft + step}px`);
                }
                // Seta Baixo (40)
                else if (e.which === 40) {
                    e.preventDefault();
                    selectedElement.css('top', `${curTop + step}px`);
                }
                // Tecla Delete (46)
                else if (e.which === 46) {
                    e.preventDefault();
                    $('#deleteButton').trigger('click');
                }
                // Atalho Ctrl + D para Duplicar
                else if (e.which === 68 && (e.ctrlKey || e.metaKey)) {
                    e.preventDefault();
                    $('#duplicateButton').trigger('click');
                }
            }
        });

        // Botão Fechar Editor (ESC)
        $(document).on('click', '#editorCloseBtn', function (e) {
            e.preventDefault();
            closeUI();
        });

        // Botão Exit no painel de gestão
        $(document).on('click', '#exit_button, [data-tab="exit"]', function (e) {
            e.preventDefault();
            closeUI();
        });
    }

    // ─── LOCALIZAÇÃO NUI ───────────────────────────────────────────
    function applyLocales(texts) {
        if (!texts || typeof texts !== 'object') return;
        for (const [key, val] of Object.entries(texts)) {
            try {
                const el = document.getElementById(key);
                if (el && typeof val === 'string') {
                    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                        el.setAttribute('placeholder', val);
                    } else {
                        el.textContent = val;
                    }
                }
            } catch (e) {
                // Ignore any invalid element ID safely
            }
        }
    }

})();