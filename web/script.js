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
                $('.container31').hide();
                $('.container').show();
                $('.controlPage').show();
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
                $('.container31').hide();
                $('.container').show();
                $('.controlPage').hide(); // Esconde ferramentas de edição
                renderPageContent(item.texts);
                updatePaginationDisplay();
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

            case 'manager':
                // Abre Painel de Gestão da Empresa
                $('.container').hide();
                $('.container31').show();
                renderManagementDashboard(item.data);
                break;
        }
    });

    // ─── RENDERIZADOR DE ELEMENTOS DA PÁGINA ───────────────────────
    function renderPageContent(elements) {
        const $page = $('.page');
        $page.empty();
        selectedElement = null;
        updateSelectedElementControls();

        if (typeof elements === 'string') {
            try {
                elements = JSON.parse(elements);
            } catch (e) {
                elements = [];
            }
        }

        if (!Array.isArray(elements)) elements = [];

        elements.forEach(item => {
            if (!item || !item.type) return;

            elementsCounter = Math.max(elementsCounter, (parseInt(item.id, 10) || 0) + 1);
            let $el;

            if (item.type === 'text') {
                $el = $('<div class="draggable"></div>');
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'text');
                $el.text(item.content || item.text || 'Texto'); // Seguro: text() escapa tags

                if (item.fontFamily) $el.css('font-family', item.fontFamily);
                if (item.fontSize) $el.css('font-size', item.fontSize);
                if (item.color) $el.css('color', item.color);
                if (item.opacity) $el.css('opacity', item.opacity);
                if (item.letterSpacing) $el.css('letter-spacing', item.letterSpacing);
                if (item.fontWeight) $el.css('font-weight', item.fontWeight);
                if (item.textAlign) $el.css('text-align', item.textAlign);

            } else if (item.type === 'image') {
                const safeUrl = sanitizeImageUrl(item.src || item.url);
                if (!safeUrl) return;

                $el = $('<div class="draggable"><img style="width:100%; height:100%; object-fit:cover; pointer-events:none;" /></div>');
                $el.attr('data-id', item.id || elementsCounter);
                $el.attr('data-type', 'image');
                $el.find('img').attr('src', safeUrl);

                if (item.width) $el.css('width', item.width);
                if (item.height) $el.css('height', item.height);
                if (item.opacity) $el.css('opacity', item.opacity);
            }

            if ($el) {
                $el.css({
                    top: item.top || '10px',
                    left: item.left || '10px',
                    position: 'absolute'
                });

                if (isEditorMode) {
                    $el.attr('contenteditable', item.type === 'text' ? 'true' : 'false');
                    attachDraggable($el);
                } else {
                    $el.attr('contenteditable', 'false');
                }

                $page.append($el);
            }
        });
    }

    function attachDraggable($el) {
        $el.draggable({
            containment: '.page',
            stop: function () {
                selectElement($(this));
            }
        });

        $el.on('click', function (e) {
            e.stopPropagation();
            if (isEditorMode) {
                selectElement($(this));
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

    function updateSelectedElementControls() {
        const hasSelection = selectedElement !== null;
        $('#saveButton').prop('disabled', false);
        $('#deleteButton').prop('disabled', !hasSelection);
        $('#textLeft, #textCenter, #textRight').prop('disabled', !hasSelection);

        if (hasSelection && selectedElement.attr('data-type') === 'text') {
            const fs = parseInt(selectedElement.css('font-size'), 10) || 16;
            $('#sizeInput').val(fs);
            const op = Math.round((parseFloat(selectedElement.css('opacity')) || 1) * 10);
            $('#elementOpactiy').val(op);
        }
    }

    // ─── CONFIGURAÇÃO DE CONTROLES DO EDITOR ───────────────────────
    function setupEditorControls() {
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

        // Adicionar Texto
        $('#addText').on('click', function () {
            elementsCounter++;
            const $el = $('<div class="draggable" contenteditable="true">Novo Texto</div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'text');
            $el.css({
                top: '50px',
                left: '50px',
                position: 'absolute',
                fontSize: '18px',
                color: '#000000',
                fontFamily: 'Montserrat'
            });

            attachDraggable($el);
            $('.page').append($el);
            selectElement($el);
        });

        // Adicionar Imagem
        $('#addImage').on('click', function () {
            const rawUrl = $('#imageInput').val();
            const safeUrl = sanitizeImageUrl(rawUrl);

            if (!safeUrl) {
                nuiFetch('notify', { notify: 'enterImageURL' });
                return;
            }

            const w = parseInt($('#imageWidth').val(), 10) || 20;
            const h = parseInt($('#imageHeight').val(), 10) || 20;

            elementsCounter++;
            const $el = $('<div class="draggable"><img style="width:100%; height:100%; object-fit:cover; pointer-events:none;" /></div>');
            $el.attr('data-id', elementsCounter);
            $el.attr('data-type', 'image');
            $el.find('img').attr('src', safeUrl);
            $el.css({
                top: '50px',
                left: '50px',
                width: `${w * 10}px`,
                height: `${h * 10}px`,
                position: 'absolute'
            });

            attachDraggable($el);
            $('.page').append($el);
            selectElement($el);
            $('#imageInput').val('');
        });

        // Estilos de Texto
        $('#sizeInput').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const sz = parseInt($(this).val(), 10) || 16;
                selectedElement.css('font-size', `${sz}px`);
            }
        });

        $('#colorPicker').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                selectedElement.css('color', $(this).val());
            }
        });

        $('#elementOpactiy').on('input', function () {
            if (selectedElement) {
                const op = (parseInt($(this).val(), 10) || 10) / 10;
                selectedElement.css('opacity', op);
            }
        });

        $('#textSpace').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const sp = parseInt($(this).val(), 10) || 0;
                selectedElement.css('letter-spacing', `${sp}px`);
            }
        });

        $('#textWeight').on('input', function () {
            if (selectedElement && selectedElement.attr('data-type') === 'text') {
                const w = (parseInt($(this).val(), 10) || 4) * 100;
                selectedElement.css('font-weight', w);
            }
        });

        $('#textLeft').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'left');
        });

        $('#textCenter').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'center');
        });

        $('#textRight').on('click', function () {
            if (selectedElement) selectedElement.css('text-align', 'right');
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
        });
    }

    function serializePage() {
        const elements = [];
        $('.page .draggable').each(function () {
            const $this = $(this);
            const type = $this.attr('data-type') || 'text';
            const id = $this.attr('data-id');

            const item = {
                id: id,
                type: type,
                top: $this.css('top'),
                left: $this.css('left'),
                opacity: $this.css('opacity')
            };

            if (type === 'text') {
                item.text = $this.text(); // Usa text() seguro
                item.fontSize = $this.css('font-size');
                item.color = $this.css('color');
                item.fontFamily = $this.css('font-family');
                item.fontWeight = $this.css('font-weight');
                item.letterSpacing = $this.css('letter-spacing');
                item.textAlign = $this.css('text-align');
            } else if (type === 'image') {
                item.src = sanitizeImageUrl($this.find('img').attr('src'));
                item.width = $this.css('width');
                item.height = $this.css('height');
            }

            elements.push(item);
        });
        return elements;
    }

    function updatePaginationDisplay() {
        $('#currentPageNumber').text(currentPage);
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
            $('#newspaperPrice').text(`Preço do Jornal ($${data.newspaperPrice})`);
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
        $('.container').hide();
        $('.container31').hide();
        selectElement(null);

        if (isEditorMode) {
            nuiFetch('exit2');
            isEditorMode = false;
        } else {
            nuiFetch('exit');
        }
    }

    function setupKeyboardShortcuts() {
        $(document).on('keyup', function (e) {
            // Tecla ESC (27) ou Backspace fora de inputs
            if (e.which === 27) {
                closeUI();
            }
        });
    }

    // ─── LOCALIZAÇÃO NUI ───────────────────────────────────────────
    function applyLocales(texts) {
        if (!texts || typeof texts !== 'object') return;
        for (const [key, val] of Object.entries(texts)) {
            const $el = $(`#${key}`);
            if ($el.length && typeof val === 'string') {
                if ($el.is('input') || $el.is('textarea')) {
                    $el.attr('placeholder', val);
                } else {
                    $el.text(val);
                }
            }
        }
    }

})();