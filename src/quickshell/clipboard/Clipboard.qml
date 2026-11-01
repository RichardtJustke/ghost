import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"

PanelWindow {
    id: clipboardWindow

    screen: ClipboardController.screen

    WlrLayershell.namespace: "qs-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: clipboardWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        if (typeof Scaler === "undefined" || !Scaler.s) return val;
        return Scaler.s(val, clipboardWindow.screen ? clipboardWindow.screen.name : undefined);
    }

    function closeClipboard() {
        ClipboardController.hide();
    }

    function t(key, fallback) {
        return typeof I18n !== "undefined" ? (I18n.t(key, fallback) || fallback) : fallback;
    }

    // Created on first open; held false for one tick so the open handler and intro animation run
    property bool lazyReady: false
    property bool isVisible: lazyReady && ClipboardController.isVisible

    Component.onCompleted: Qt.callLater(() => { clipboardWindow.lazyReady = true; })
    property int configRevision: 0
    property bool isDirty: true

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            ClipboardController.hide();
            clipboardWindow.configRevision++;
        }
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }
    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isFullscreenActive: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real innerRadius: Math.min(ThemeBackend.borderRadius, s(10))
    property real clipRowHeight: s(38)

    visible: isVisible || container.animProgress > 0.001

    property var allFetchedClips: []
    property int clipPageSize: 60
    property int clipOffset: 0
    property bool hasMoreClips: true
    property bool fetchPending: false

    // Snapshot of the clip under clipList.currentIndex, shown in the preview pane
    property var selectedClip: null
    property string previewClipId: ""
    property string previewFullText: ""
    property string fetchingClipId: ""
    property bool isClearingClips: false

    readonly property bool selectedIsImage: selectedClip !== null && selectedClip.type === "image"
    readonly property string selectedText: {
        if (!selectedClip || selectedIsImage) return "";
        return previewClipId === selectedClip.id && previewFullText !== "" ? previewFullText : selectedClip.content;
    }

    property bool isKeyboardNav: false
    property string pendingQuery: ""

    function grabInputFocus() {
        searchInput.forceActiveFocus();
        if (typeof searchInput.forceInputFocus === "function") {
            searchInput.forceInputFocus();
        }
    }

    function fileUrl(path) {
        return path.startsWith("file://") ? path : "file://" + path;
    }

    function clipTypeLabel() {
        if (!selectedClip) return "";
        if (selectedIsImage) return t("clipboard.imageType", "Image");
        if (/^https?:\/\/\S+$/.test(selectedClip.content.trim())) return t("clipboard.linkType", "Link");
        return t("clipboard.textType", "Text");
    }

    function clipSizeLabel() {
        if (!selectedClip) return "";
        if (selectedIsImage) {
            return previewImage.status === Image.Ready ? previewImage.implicitWidth + " × " + previewImage.implicitHeight : "";
        }
        return selectedText.length + " " + t("clipboard.characters", "characters");
    }

    function syncSelection() {
        if (clipBoxModel.count > 0 && (clipList.currentIndex < 0 || clipList.currentIndex >= clipBoxModel.count)) {
            clipList.currentIndex = Math.min(Math.max(0, clipList.currentIndex), clipBoxModel.count - 1);
        }
        let item = clipList.currentIndex >= 0 && clipList.currentIndex < clipBoxModel.count ? clipBoxModel.get(clipList.currentIndex) : null;
        if (!item) {
            selectedClip = null;
            previewClipId = "";
            previewFullText = "";
            previewFetchDebounce.stop();
            return;
        }

        let id = item.id.toString();
        selectedClip = {
            id: id,
            content: item.content || "",
            type: item.type,
            pinned: item.pinned,
            section: item.sectionCategory
        };

        if (item.type === "image") {
            previewClipId = "";
            previewFullText = "";
            previewFetchDebounce.stop();
        } else if (previewClipId !== id) {
            previewClipId = id;
            previewFullText = "";
            previewFetchDebounce.restart();
        }
    }

    function fetchPreviewText() {
        if (previewClipId === "" || fullTextFetcher.running) return;
        fetchingClipId = previewClipId;
        fullTextFetcher.command = ["cliphist", "decode", fetchingClipId];
        fullTextFetcher.running = true;
    }

    ListModel {
        id: clipBoxModel
    }

    Process {
        id: clipWatcher
        running: true
        command: ["wl-paste", "--watch", "echo", "1"]
        stdout: SplitParser {
            onRead: (data) => {
                if (clipboardWindow.isVisible) {
                    clipWatchDebounce.restart();
                } else {
                    clipboardWindow.isDirty = true;
                }
            }
        }
    }

    Timer {
        id: clipWatchDebounce
        interval: 150
        repeat: false
        onTriggered: {
            clipboardWindow.refreshClips();
        }
    }

    // Holding an arrow key shouldn't spawn a cliphist process per row
    Timer {
        id: previewFetchDebounce
        interval: 60
        repeat: false
        onTriggered: clipboardWindow.fetchPreviewText()
    }

    Process {
        id: fullTextFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (clipboardWindow.fetchingClipId === clipboardWindow.previewClipId) {
                    clipboardWindow.previewFullText = this.text || "";
                } else {
                    Qt.callLater(clipboardWindow.fetchPreviewText);
                }
            }
        }
    }

    function isSubsequence(sub, str) {
        let i = 0;
        let j = 0;
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) {
                i++;
            }
            j++;
        }
        return i === sub.length;
    }

    function syncClipBoxModel(targetItems) {
        for (let i = 0; i < targetItems.length; i++) {
            let item = targetItems[i];
            if (i < clipBoxModel.count) {
                let cur = clipBoxModel.get(i);
                if (cur.id !== item.id || cur.pinned !== item.pinned || cur.content !== item.content || cur.type !== item.type || cur.sectionCategory !== item.sectionCategory || cur.score !== item.score) {
                    clipBoxModel.set(i, item);
                }
            } else {
                clipBoxModel.append(item);
            }
        }

        while (clipBoxModel.count > targetItems.length) {
            clipBoxModel.remove(clipBoxModel.count - 1);
        }
    }

    function executeClipFilter(query, keepClipId) {
        clipboardWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let rawTrimmed = (query || "").trim();
        let q = rawTrimmed.toLowerCase();
        let filtered = [];

        let pinnedLabel = t("clipboard.pinned", "Pinned");
        let recentLabel = t("clipboard.recent", "Recent");

        for (let i = 0; i < clipboardWindow.allFetchedClips.length; i++) {
            let item = clipboardWindow.allFetchedClips[i];
            let contentLower = (item.content || "").toLowerCase();
            let matchQuality = 0;
            let matches = false;

            if (q.length === 0) {
                matches = true;
            } else {
                if (contentLower === q) {
                    matchQuality = 100000;
                    matches = true;
                } else if (contentLower.startsWith(q)) {
                    matchQuality = 50000;
                    matches = true;
                } else if (contentLower.includes(q)) {
                    matchQuality = 10000;
                    matches = true;
                } else if (isSubsequence(q, contentLower)) {
                    matchQuality = 1000;
                    matches = true;
                }
            }

            if (matches) {
                filtered.push({
                    id: item.id,
                    pinned: Boolean(item.pinned),
                    content: item.content || "",
                    type: item.type || "text",
                    sectionCategory: item.pinned ? pinnedLabel : recentLabel,
                    score: (item.pinned ? 500000 : 0) + matchQuality
                });
            }
        }

        if (q.length > 0) {
            filtered.sort(function(a, b) {
                if (a.score !== b.score) {
                    return b.score - a.score;
                }
                return 0;
            });
        } else {
            let pinnedItems = [];
            let unpinnedItems = [];
            for (let i = 0; i < filtered.length; i++) {
                if (filtered[i].pinned) pinnedItems.push(filtered[i]);
                else unpinnedItems.push(filtered[i]);
            }
            filtered = pinnedItems.concat(unpinnedItems);
        }

        syncClipBoxModel(filtered);

        clipList.resetScroll();

        let nextIndex = clipBoxModel.count > 0 ? 0 : -1;
        if (keepClipId) {
            for (let i = 0; i < filtered.length; i++) {
                if (filtered[i].id.toString() === keepClipId) {
                    nextIndex = i;
                    break;
                }
            }
        }
        clipList.currentIndex = nextIndex;
        if (nextIndex > 0) clipList.ensureVisible(nextIndex, false);
        syncSelection();
    }

    function filterClips(query) {
        clipboardWindow.pendingQuery = query;
        filterDebounceTimer.restart();
    }

    Timer {
        id: filterDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            clipboardWindow.executeClipFilter(clipboardWindow.pendingQuery);
        }
    }

    Process {
        id: clipFetcherProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (clipboardWindow.fetchPending) {
                    clipboardWindow.fetchPending = false;
                    clipboardWindow.clipOffset = 0;
                    clipboardWindow.hasMoreClips = true;
                    clipboardWindow.fetchNextClipPage();
                    return;
                }

                try {
                    let txt = this.text.trim();
                    if (txt.length > 0) {
                        let items = JSON.parse(txt);
                        if (items.length < clipboardWindow.clipPageSize) {
                            clipboardWindow.hasMoreClips = false;
                        }

                        // Later pages only extend the list: the selection stays where it is
                        let keepClipId = clipboardWindow.clipOffset > 0 && clipboardWindow.selectedClip ? clipboardWindow.selectedClip.id : "";
                        if (clipboardWindow.clipOffset === 0) {
                            clipboardWindow.allFetchedClips = items;
                        } else {
                            let existingIds = {};
                            for (let i = 0; i < clipboardWindow.allFetchedClips.length; i++) {
                                existingIds[clipboardWindow.allFetchedClips[i].id] = true;
                            }
                            for (let i = 0; i < items.length; i++) {
                                if (!existingIds[items[i].id]) {
                                    clipboardWindow.allFetchedClips.push(items[i]);
                                    existingIds[items[i].id] = true;
                                }
                            }
                        }
                        clipboardWindow.clipOffset = clipboardWindow.allFetchedClips.length;
                        clipboardWindow.executeClipFilter(searchInput.text, keepClipId);
                    } else {
                        clipboardWindow.hasMoreClips = false;
                        if (clipboardWindow.clipOffset === 0) {
                            clipboardWindow.allFetchedClips = [];
                            clipboardWindow.executeClipFilter(searchInput.text);
                        }
                    }
                } catch(e) {
                    clipboardWindow.hasMoreClips = false;
                }
            }
        }
    }

    Process {
        id: clipActionProc
        running: false
    }

    function refreshClips() {
        clipboardWindow.clipOffset = 0;
        clipboardWindow.hasMoreClips = true;
        if (clipFetcherProc.running) {
            clipboardWindow.fetchPending = true;
            return;
        }
        fetchNextClipPage();
    }

    function fetchNextClipPage() {
        if (clipFetcherProc.running || !clipboardWindow.hasMoreClips) return;
        let qsDir = (typeof Caching !== "undefined" && Caching.qsDir) ? Caching.qsDir : "";
        let cacheDir = (typeof Caching !== "undefined" && Caching.getCacheDir) ? Caching.getCacheDir("clipboard") : "";
        clipFetcherProc.command = ["python3", qsDir + "/clipboard/clip_fetcher.py", clipboardWindow.clipOffset.toString(), clipboardWindow.clipPageSize.toString(), cacheDir];
        clipFetcherProc.running = true;
    }

    function copyClip(id, isPinned) {
        if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");
        if (isPinned) {
            Quickshell.execDetached(["bash", "-c", "cliphist decode " + id + " | wl-copy && (sleep 0.15; NEW_ID=$(cliphist list | head -n 1 | awk '{print $1}'); python3 " + Caching.qsDir + "/clipboard/clip_fetcher.py pin $NEW_ID " + Caching.getCacheDir("clipboard") + ") &"]);
        } else {
            Quickshell.execDetached(["bash", "-c", "cliphist decode " + id + " | wl-copy"]);
        }
        closeClipboard();
    }

    function pinClip(id) {
        clipActionProc.command = ["python3", Caching.qsDir + "/clipboard/clip_fetcher.py", "pin", id.toString(), Caching.getCacheDir("clipboard")];
        clipActionProc.running = true;
        for (let i = 0; i < clipboardWindow.allFetchedClips.length; i++) {
            if (clipboardWindow.allFetchedClips[i].id.toString() === id.toString()) {
                clipboardWindow.allFetchedClips[i].pinned = !clipboardWindow.allFetchedClips[i].pinned;
                break;
            }
        }
        clipboardWindow.executeClipFilter(searchInput.text, id.toString());
    }

    function deleteClip(id, index) {
        clipActionProc.command = ["python3", Caching.qsDir + "/clipboard/clip_fetcher.py", "delete", id.toString(), Caching.getCacheDir("clipboard")];
        clipActionProc.running = true;
        clipboardWindow.allFetchedClips = clipboardWindow.allFetchedClips.filter(item => item.id.toString() !== id.toString());
        clipBoxModel.remove(index);
        Qt.callLater(clipboardWindow.syncSelection);
    }

    function clearAllClips() {
        clipboardWindow.allFetchedClips = [];
        clipBoxModel.clear();
        clipList.resetScroll();
        syncSelection();
        clipActionProc.command = ["python3", Caching.qsDir + "/clipboard/clip_fetcher.py", "wipe", Caching.getCacheDir("clipboard")];
        clipActionProc.running = true;
    }

    Timer {
        id: clearFinishTimer
        interval: 300
        repeat: false
        onTriggered: {
            clipboardWindow.clearAllClips();
            clipboardWindow.isClearingClips = false;
        }
    }

    function animateClear() {
        if (clipboardWindow.isClearingClips || clipBoxModel.count === 0) return;
        clipboardWindow.isClearingClips = true;

        let visibleDelegates = [];
        for (let i = 0; i < clipList.contentItem.children.length; i++) {
            let child = clipList.contentItem.children[i];
            if (child && typeof child.triggerClearSlide === "function") {
                if (child.y + child.height >= clipList.contentY && child.y <= clipList.contentY + clipList.height) {
                    visibleDelegates.push(child);
                }
            }
        }

        visibleDelegates.sort((a, b) => a.y - b.y);

        if (visibleDelegates.length === 0) {
            clipboardWindow.clearAllClips();
            clipboardWindow.isClearingClips = false;
            return;
        }

        let step = 50;
        let totalTime = 0;
        for (let i = 0; i < visibleDelegates.length; i++) {
            let d = i * step;
            visibleDelegates[i].triggerClearSlide(d);
            totalTime = d + 220;
        }

        clearFinishTimer.interval = totalTime + 40;
        clearFinishTimer.start();
    }

    function activateIndex(index) {
        if (index < 0 || index >= clipBoxModel.count) return;
        let item = clipBoxModel.get(index);
        if (!item) return;
        copyClip(item.id, item.pinned);
    }

    Item {
        id: topBarHole

        property real thicknessRatio: {
            let h = (clipboardWindow.rawBarSettings && clipboardWindow.rawBarSettings.height !== undefined) ? Number(clipboardWindow.rawBarSettings.height) : 40;
            if (isNaN(h)) h = 40;
            return Math.max(28, Math.min(48, h)) / 40;
        }
        property int barThickness: Math.round(48 * thicknessRatio)
        property string bp: clipboardWindow.barPosition
        property bool activeBar: !clipboardWindow.isBarEffectivelyHidden

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return clipboardWindow.width - barThickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return clipboardWindow.height - barThickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            return clipboardWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            return clipboardWindow.height;
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            clipboardWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 120
        repeat: false
        onTriggered: {
            clipboardWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusFinalTimer
        interval: 250
        repeat: false
        onTriggered: {
            clipboardWindow.grabInputFocus();
        }
    }

    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: {
            clipboardWindow.isKeyboardNav = false;
        }
    }

    onIsVisibleChanged: {
        if (isVisible) {
            searchInput.clear();
            filterDebounceTimer.stop();
            if (clipboardWindow.isDirty || clipboardWindow.allFetchedClips.length === 0) {
                clipboardWindow.isDirty = false;
                refreshClips();
            } else {
                executeClipFilter("");
            }
            clipboardWindow.grabInputFocus();
            focusTimer.restart();
            focusRetryTimer.restart();
            focusFinalTimer.restart();
        } else {
            clipList.resetScroll();
            filterDebounceTimer.stop();
            focusTimer.stop();
            focusRetryTimer.stop();
            focusFinalTimer.stop();
            keyboardNavTimer.stop();
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: clipboardWindow.isVisible
        onClicked: closeClipboard()
    }

    Item {
        id: container

        MouseArea {
            anchors.fill: parent
        }

        property real animProgress: clipboardWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: clipboardWindow.isVisible ? 420 : 200
                easing.type: clipboardWindow.isVisible ? Easing.OutBack : Easing.InQuad
                easing.overshoot: clipboardWindow.isVisible ? 1.28 : 1.0
            }
        }

        // Centered like the launcher, kept inside small screens
        width: Math.min(clipboardWindow.s(880), Math.round(clipboardWindow.width * 0.94))
        height: Math.min(clipboardWindow.s(520), Math.round(clipboardWindow.height * 0.86))
        x: Math.floor((clipboardWindow.width - width) / 2)
        y: Math.floor((clipboardWindow.height - height) / 2)

        opacity: Math.max(0.0, Math.min(1.0, animProgress * 1.5))
        scale: 0.94 + 0.06 * animProgress
        transformOrigin: Item.Center

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: clipboardWindow.cornerRadius
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            border.width: 1
            border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0
                LayoutMirroring.enabled: I18n.rtl
                LayoutMirroring.childrenInherit: true

                Item {
                    id: listPane
                    Layout.preferredWidth: Math.round(container.width * 0.39)
                    Layout.fillHeight: true

                    RowLayout {
                        id: searchRow
                        z: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: clipboardWindow.s(14)
                        height: clipboardWindow.s(36)
                        spacing: clipboardWindow.s(8)

                        Input {
                            id: searchInput
                            focus: true
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: clipboardWindow.s(36)

                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: clipboardWindow.innerRadius
                            fontPixelSize: clipboardWindow.s(12)
                            charSpacing: 1

                            placeholderText: clipboardWindow.t("clipboard.search", "Search clipboard")
                            showClearButton: true

                            onHasFocusChanged: {
                                if (!searchInput.hasFocus && clipboardWindow.isVisible) {
                                    clipList.forceActiveFocus();
                                }
                            }

                            onTextEdited: function(newText) {
                                filterClips(newText);
                            }
                            onCleared: filterClips("")

                            Keys.onDownPressed: function(event) {
                                clipboardWindow.isKeyboardNav = true;
                                keyboardNavTimer.restart();
                                if (clipList.currentIndex < clipBoxModel.count - 1) {
                                    clipList.currentIndex++;
                                }
                                event.accepted = true;
                            }
                            Keys.onUpPressed: function(event) {
                                clipboardWindow.isKeyboardNav = true;
                                keyboardNavTimer.restart();
                                if (clipList.currentIndex > 0) {
                                    clipList.currentIndex--;
                                }
                                event.accepted = true;
                            }
                            Keys.onTabPressed: function(event) {
                                event.accepted = true;
                            }
                            Keys.onBacktabPressed: function(event) {
                                event.accepted = true;
                            }
                            Keys.onReturnPressed: function(event) {
                                activateIndex(clipList.currentIndex);
                                event.accepted = true;
                            }
                            Keys.onDeletePressed: function(event) {
                                if (clipList.currentIndex >= 0 && clipList.currentIndex < clipBoxModel.count) {
                                    let item = clipBoxModel.get(clipList.currentIndex);
                                    if (item) {
                                        deleteClip(item.id, clipList.currentIndex);
                                    }
                                }
                                event.accepted = true;
                            }
                            Keys.onEscapePressed: function(event) {
                                closeClipboard();
                                event.accepted = true;
                            }
                        }

                        ClickButton {
                            id: clearBtn
                            enabled: !clipboardWindow.isClearingClips && clipBoxModel.count > 0
                            Layout.preferredWidth: clipboardWindow.s(36)
                            Layout.preferredHeight: clipboardWindow.s(36)
                            horizontalPadding: 0
                            cornerRadius: clipboardWindow.innerRadius
                            buttonIcon: "󰆴"
                            iconFontSize: clipboardWindow.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text

                            onTriggered: {
                                clipboardWindow.animateClear();
                            }
                        }
                    }

                    Item {
                        id: listContainer
                        z: 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: searchRow.bottom
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: clipboardWindow.s(14)
                        anchors.rightMargin: clipboardWindow.s(14)
                        anchors.topMargin: clipboardWindow.s(10)
                        anchors.bottomMargin: clipboardWindow.s(14)
                        clip: true

                        NumberAnimation {
                            id: scrollAnim
                            target: clipList
                            property: "contentY"
                            duration: 260
                            easing.type: Easing.OutCubic
                        }

                        ListView {
                            id: clipList
                            anchors.fill: parent
                            clip: true
                            model: clipBoxModel
                            spacing: clipboardWindow.s(2)
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: clipboardWindow.s(600)
                            interactive: !clipboardWindow.isClearingClips && (contentHeight > height)

                            highlightFollowsCurrentItem: false

                            Keys.forwardTo: [searchInput]

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Backspace) {
                                    clipboardWindow.grabInputFocus();
                                    if (searchInput.text.length > 0) {
                                        searchInput.text = searchInput.text.slice(0, -1);
                                    }
                                    event.accepted = true;
                                    return;
                                }
                                if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab && event.key !== Qt.Key_Delete) {
                                    clipboardWindow.grabInputFocus();
                                    searchInput.text += event.text;
                                    event.accepted = true;
                                }
                            }

                            function resetScroll() {
                                scrollAnim.stop();
                                positionViewAtBeginning();
                                contentY = 0;
                            }

                            function getItemBounds(idx) {
                                if (idx < 0 || idx >= clipBoxModel.count) return null;
                                let secH = clipboardWindow.s(22);
                                let rowH = clipboardWindow.clipRowHeight;
                                let itemObj = itemAtIndex(idx);
                                let isFirstInSection = false;
                                let curItem = clipBoxModel.get(idx);
                                if (curItem) {
                                    if (idx === 0) {
                                        isFirstInSection = (curItem.sectionCategory !== undefined && curItem.sectionCategory !== "");
                                    } else {
                                        let prevItem = clipBoxModel.get(idx - 1);
                                        if (prevItem && curItem.sectionCategory !== prevItem.sectionCategory) {
                                            isFirstInSection = true;
                                        }
                                    }
                                }

                                if (itemObj) {
                                    let topY = Math.max(0, itemObj.y - (isFirstInSection ? secH : 0));
                                    return { top: topY, bottom: itemObj.y + itemObj.height };
                                }

                                let curY = 0;
                                let prevSec = "";
                                for (let i = 0; i <= idx; i++) {
                                    let m = clipBoxModel.get(i);
                                    if (!m) break;
                                    let sec = m.sectionCategory || "";
                                    let hasSec = (sec !== "" && sec !== prevSec);
                                    if (hasSec) {
                                        curY += secH;
                                        prevSec = sec;
                                    }
                                    if (i === idx) {
                                        return { top: Math.max(0, curY - (hasSec ? secH : 0)), bottom: curY + rowH };
                                    }
                                    curY += rowH + spacing;
                                }
                                return { top: Math.max(0, curY), bottom: curY + rowH };
                            }

                            function ensureVisible(idx, animated) {
                                if (idx < 0 || clipBoxModel.count === 0) return;
                                let bounds = getItemBounds(idx);
                                if (!bounds) return;

                                let curContentY = scrollAnim.running ? scrollAnim.to : contentY;
                                let maxScroll = Math.max(0, Math.max(contentHeight, bounds.bottom) - height);
                                let newContentY = curContentY;

                                if (bounds.top < curContentY) {
                                    newContentY = bounds.top;
                                } else if (bounds.bottom > curContentY + height) {
                                    newContentY = bounds.bottom - height;
                                }

                                newContentY = Math.max(0, Math.min(maxScroll, newContentY));

                                if (Math.abs(newContentY - contentY) > 0.5) {
                                    if (animated) {
                                        scrollAnim.stop();
                                        scrollAnim.from = contentY;
                                        scrollAnim.to = newContentY;
                                        scrollAnim.start();
                                    } else {
                                        scrollAnim.stop();
                                        contentY = newContentY;
                                    }
                                }
                            }

                            onMovementStarted: {
                                scrollAnim.stop();
                            }

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    ensureVisible(currentIndex, clipboardWindow.isKeyboardNav);
                                }
                                clipboardWindow.syncSelection();
                            }

                            section.property: "sectionCategory"
                            section.criteria: ViewSection.FullString
                            section.delegate: Item {
                                width: ListView.view ? ListView.view.width : 0
                                height: clipboardWindow.s(22)
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: clipboardWindow.s(4)
                                    anchors.rightMargin: clipboardWindow.s(4)
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: I18n.textAlignment
                                    text: section
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: clipboardWindow.s(10.5)
                                    color: ThemeBackend.subtext0
                                    opacity: 0.85
                                }
                            }

                            add: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0.0
                                    to: 1.0
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    from: 0.96
                                    to: 1.0
                                    duration: 270
                                    easing.type: Easing.OutCubic
                                }
                            }

                            remove: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    to: 0.0
                                    duration: 170
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    property: "scale"
                                    to: 0.96
                                    duration: 170
                                    easing.type: Easing.OutCubic
                                }
                            }

                            displaced: null

                            onContentYChanged: {
                                if (contentY < 0 && !moving && !flicking) {
                                    contentY = 0;
                                }
                                if (clipboardWindow.hasMoreClips && !clipFetcherProc.running && searchInput.text.trim().length === 0) {
                                    if (contentY + height >= contentHeight - clipboardWindow.s(450)) {
                                        clipboardWindow.fetchNextClipPage();
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: clipList.moving || clipList.movingVertically
                                width: clipboardWindow.s(4)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle { implicitWidth: clipboardWindow.s(4); radius: clipboardWindow.s(2); color: ThemeBackend.surface2 }
                            }

                            delegate: Item {
                                id: clipDelegateWrapper
                                width: ListView.view ? ListView.view.width : 0
                                height: clipboardWindow.clipRowHeight
                                z: isSelected ? 2 : 1

                                property bool isSelected: index === clipList.currentIndex
                                readonly property bool isImage: model.type === "image"

                                scale: clipCardMa.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                property string clipIdString: (typeof model !== "undefined" && model && model.id !== undefined) ? model.id.toString() : (clipBoxModel.get(index) ? clipBoxModel.get(index).id.toString() : "")

                                onClipIdStringChanged: {
                                    dragX = 0;
                                }

                                property real dragX: 0

                                property real clearDelay: 0
                                NumberAnimation {
                                    id: clearSlideAnim
                                    target: clipDelegateWrapper
                                    property: "dragX"
                                    to: clipList.width * 1.2
                                    duration: 220
                                    easing.type: Easing.OutQuad
                                }
                                Timer {
                                    id: clearSlideTimer
                                    interval: clipDelegateWrapper.clearDelay
                                    onTriggered: clearSlideAnim.start()
                                }
                                function triggerClearSlide(delayMs) {
                                    clearDelay = delayMs;
                                    clearSlideTimer.start();
                                }

                                NumberAnimation {
                                    id: clipResetAnim
                                    target: clipDelegateWrapper
                                    property: "dragX"
                                    from: clipDelegateWrapper.dragX
                                    to: 0
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    id: clipDismissAnim
                                    target: clipDelegateWrapper
                                    property: "dragX"
                                    from: clipDelegateWrapper.dragX
                                    to: 0
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                    onFinished: clipboardWindow.deleteClip(clipDelegateWrapper.clipIdString, index)
                                }

                                Rectangle {
                                    id: clipDelegateCard
                                    anchors.fill: parent

                                    transform: Translate { x: clipDelegateWrapper.dragX }
                                    opacity: Math.max(0.0, 1.0 - (Math.abs(clipDelegateWrapper.dragX) / (clipDelegateCard.width * 0.75)))

                                    radius: clipboardWindow.innerRadius
                                    color: {
                                        if (clipDelegateWrapper.isSelected) return ThemeBackend.mauve;
                                        return clipCardMa.containsMouse ? ThemeBackend.surface0 : "transparent";
                                    }

                                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    MouseArea {
                                        id: clipCardMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !clipboardWindow.isClearingClips
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                                        property real startRootX: 0
                                        property bool draggingH: false

                                        onPressed: (mouse) => {
                                            clipList.currentIndex = index;
                                            startRootX = mapToItem(container, mouse.x, mouse.y).x;
                                            draggingH = false;
                                            clipResetAnim.stop();
                                        }

                                        onPositionChanged: (mouse) => {
                                            if (!pressed) return;
                                            let dx = mapToItem(container, mouse.x, mouse.y).x - startRootX;
                                            if (!draggingH && Math.abs(dx) > clipboardWindow.s(6)) {
                                                draggingH = true;
                                                clipCardMa.preventStealing = true;
                                            }
                                            if (draggingH) {
                                                clipDelegateWrapper.dragX = dx;
                                            }
                                        }

                                        onReleased: (mouse) => {
                                            clipCardMa.preventStealing = false;
                                            if (draggingH) {
                                                let threshold = clipDelegateCard.width * 0.25;
                                                if (Math.abs(clipDelegateWrapper.dragX) > threshold) {
                                                    clipDismissAnim.from = clipDelegateWrapper.dragX;
                                                    clipDismissAnim.to = clipDelegateWrapper.dragX > 0 ? clipDelegateCard.width * 1.2 : -clipDelegateCard.width * 1.2;
                                                    clipDismissAnim.start();
                                                } else {
                                                    clipResetAnim.from = clipDelegateWrapper.dragX;
                                                    clipResetAnim.start();
                                                }
                                                draggingH = false;
                                            } else if (mouse.button === Qt.RightButton) {
                                                clipboardWindow.pinClip(clipDelegateWrapper.clipIdString);
                                            }
                                        }

                                        onDoubleClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                clipboardWindow.copyClip(clipDelegateWrapper.clipIdString, model.pinned);
                                            }
                                        }

                                        onCanceled: {
                                            clipCardMa.preventStealing = false;
                                            if (draggingH) {
                                                clipResetAnim.from = clipDelegateWrapper.dragX;
                                                clipResetAnim.start();
                                                draggingH = false;
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: clipboardWindow.s(8)
                                        anchors.rightMargin: clipboardWindow.s(10)
                                        spacing: clipboardWindow.s(8)

                                        Rectangle {
                                            Layout.preferredWidth: clipboardWindow.s(24)
                                            Layout.preferredHeight: clipboardWindow.s(24)
                                            radius: clipboardWindow.s(6)
                                            color: clipDelegateWrapper.isSelected ? Qt.rgba(0, 0, 0, 0.15) : ThemeBackend.surface1

                                            Image {
                                                id: clipThumbImg
                                                anchors.fill: parent
                                                anchors.margins: clipboardWindow.s(2)
                                                source: (clipDelegateWrapper.isImage && model.content) ? clipboardWindow.fileUrl(model.content) : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                                smooth: true
                                                sourceSize.width: Math.round(clipboardWindow.s(48) * (Screen.devicePixelRatio || 1))
                                                sourceSize.height: Math.round(clipboardWindow.s(48) * (Screen.devicePixelRatio || 1))
                                                visible: clipDelegateWrapper.isImage && status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: clipboardWindow.s(13)
                                                color: clipDelegateWrapper.isSelected ? ThemeBackend.crust : ThemeBackend.subtext0
                                                text: clipDelegateWrapper.isImage ? "󰋩" : "󰈙"
                                                visible: !clipThumbImg.visible
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: {
                                                let c = model.content || "";
                                                if (clipDelegateWrapper.isImage) {
                                                    // Pasted image data lives in the cache as <cliphist id>.png
                                                    let fileName = c.split("/").pop();
                                                    return /^\d+\.png$/.test(fileName) ? clipboardWindow.t("clipboard.imageType", "Image") : fileName;
                                                }
                                                return c.replace(/\s*\n\s*/g, " ");
                                            }
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: clipboardWindow.s(12)
                                            font.weight: clipDelegateWrapper.isSelected ? Font.Bold : Font.Normal
                                            color: clipDelegateWrapper.isSelected ? ThemeBackend.crust : ThemeBackend.text
                                            horizontalAlignment: I18n.textAlignment
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: ThemeBackend.surface0
                }

                ColumnLayout {
                    id: previewPane
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.margins: clipboardWindow.s(14)
                    spacing: clipboardWindow.s(12)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: clipboardWindow.innerRadius
                        color: ThemeBackend.surface0
                        clip: true

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: clipboardWindow.s(10)
                            source: clipboardWindow.selectedIsImage ? clipboardWindow.fileUrl(clipboardWindow.selectedClip.content) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            smooth: true
                            mipmap: true
                            visible: clipboardWindow.selectedIsImage
                        }

                        Flickable {
                            id: previewFlickable
                            anchors.fill: parent
                            anchors.margins: clipboardWindow.s(14)
                            contentWidth: width
                            contentHeight: previewText.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height
                            clip: true
                            visible: clipboardWindow.selectedClip !== null && !clipboardWindow.selectedIsImage

                            ScrollBar.vertical: ScrollBar {
                                width: clipboardWindow.s(3)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle { radius: clipboardWindow.s(1.5); color: ThemeBackend.surface2 }
                            }

                            Text {
                                id: previewText
                                width: previewFlickable.width
                                horizontalAlignment: I18n.textAlignment
                                // Laying out megabytes of plain text would stall the whole shell
                                text: clipboardWindow.selectedText.slice(0, 20000)
                                onTextChanged: previewFlickable.contentY = 0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: clipboardWindow.s(13)
                                lineHeight: 1.25
                                color: ThemeBackend.text
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: clipboardWindow.selectedClip === null
                            text: clipboardWindow.t("clipboard.empty", "Nothing found")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: clipboardWindow.s(13)
                            color: ThemeBackend.subtext0
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: clipboardWindow.selectedClip !== null
                        spacing: clipboardWindow.s(10)

                        Repeater {
                            model: [
                                { label: clipboardWindow.t("clipboard.type", "Type"), value: clipboardWindow.clipTypeLabel() },
                                { label: clipboardWindow.t("clipboard.size", "Size"), value: clipboardWindow.clipSizeLabel() },
                                { label: clipboardWindow.t("clipboard.list", "List"), value: clipboardWindow.selectedClip ? clipboardWindow.selectedClip.section : "" }
                            ]

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.minimumWidth: 0
                                spacing: clipboardWindow.s(3)

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: clipboardWindow.s(11)
                                    color: ThemeBackend.subtext0
                                    horizontalAlignment: I18n.textAlignment
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: clipboardWindow.s(12)
                                    color: ThemeBackend.text
                                    horizontalAlignment: I18n.textAlignment
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: clipboardWindow.s(8)
                        enabled: clipboardWindow.selectedClip !== null
                        opacity: enabled ? 1.0 : 0.5

                        ClickButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: clipboardWindow.s(40)
                            cornerRadius: clipboardWindow.innerRadius
                            buttonText: clipboardWindow.t("clipboard.copy", "Copy")
                            textFontSize: clipboardWindow.s(13)
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            onTriggered: clipboardWindow.activateIndex(clipList.currentIndex)
                        }

                        ClickButton {
                            Layout.preferredWidth: clipboardWindow.s(100)
                            Layout.preferredHeight: clipboardWindow.s(40)
                            cornerRadius: clipboardWindow.innerRadius
                            buttonText: clipboardWindow.selectedClip && clipboardWindow.selectedClip.pinned
                                ? clipboardWindow.t("clipboard.unpin", "Unpin")
                                : clipboardWindow.t("clipboard.pin", "Pin")
                            textFontSize: clipboardWindow.s(12)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onTriggered: {
                                if (clipboardWindow.selectedClip) clipboardWindow.pinClip(clipboardWindow.selectedClip.id);
                            }
                        }

                        ClickButton {
                            Layout.preferredWidth: clipboardWindow.s(100)
                            Layout.preferredHeight: clipboardWindow.s(40)
                            cornerRadius: clipboardWindow.innerRadius
                            buttonText: clipboardWindow.t("clipboard.delete", "Delete")
                            textFontSize: clipboardWindow.s(12)
                            accentColor: ThemeBackend.surface1
                            textColor: ThemeBackend.text
                            onTriggered: {
                                if (clipboardWindow.selectedClip) clipboardWindow.deleteClip(clipboardWindow.selectedClip.id, clipList.currentIndex);
                            }
                        }
                    }
                }
            }
        }
    }
}
