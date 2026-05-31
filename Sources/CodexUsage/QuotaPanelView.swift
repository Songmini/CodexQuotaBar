import AppKit
import CodexUsageCore

@MainActor
final class QuotaPanelView: NSView {
    var onModeToggle: (() -> Void)?

    private let modeButton = PanelModeToggleButton(targetMode: .compact)
    private let brandView = PanelGaugeMarkView()
    private let titleLabel = NSTextField(labelWithString: "Codex Usage")
    private let statusLabel = NSTextField(labelWithString: "Waiting for Codex...")
    private let fiveHourRow = FullQuotaRowView()
    private let weeklyRow = FullQuotaRowView()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(_ result: QuotaReadResult) {
        switch result {
        case .idle:
            brandView.weeklyRemainingPercent = nil
            statusLabel.stringValue = "Waiting for Codex..."
            fiveHourRow.updatePlaceholder(title: "5-hour")
            weeklyRow.updatePlaceholder(title: "1-week")
            setRowsHidden(false)
        case .notApplicable:
            brandView.weeklyRemainingPercent = nil
            statusLabel.stringValue = "Usage limits apply to ChatGPT plans only."
            setRowsHidden(true)
        case .success(let snapshot):
            brandView.weeklyRemainingPercent = snapshot.weekly.remainingPercent
            statusLabel.stringValue = "Updated \(dateFormatter.string(from: snapshot.readAt))"
            fiveHourRow.update(snapshot.fiveHour)
            weeklyRow.update(snapshot.weekly)
            setRowsHidden(false)
        case .failure(let error, let lastSnapshot):
            if let lastSnapshot {
                brandView.weeklyRemainingPercent = lastSnapshot.weekly.remainingPercent
                statusLabel.stringValue = "\(error.message). Last updated \(dateFormatter.string(from: lastSnapshot.readAt))"
                fiveHourRow.update(lastSnapshot.fiveHour)
                weeklyRow.update(lastSnapshot.weekly)
            } else {
                brandView.weeklyRemainingPercent = nil
                statusLabel.stringValue = error.message
                fiveHourRow.updatePlaceholder(title: "5-hour")
                weeklyRow.updatePlaceholder(title: "1-week")
            }
            setRowsHidden(false)
        }
    }

    private func setRowsHidden(_ hidden: Bool) {
        fiveHourRow.isHidden = hidden
        weeklyRow.isHidden = hidden
    }

    @objc private func toggleMode() {
        onModeToggle?()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.114, green: 0.118, blue: 0.133, alpha: 0.98).cgColor
        layer?.cornerRadius = 28
        layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.14).cgColor
        layer?.borderWidth = 1
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.24
        layer?.shadowRadius = 18
        layer?.shadowOffset = NSSize(width: 0, height: -6)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail

        statusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = NSColor(calibratedWhite: 0.70, alpha: 1)
        statusLabel.lineBreakMode = .byTruncatingTail

        modeButton.onClick = { [weak self] in
            self?.toggleMode()
        }
        modeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modeButton)

        let titleStack = NSStackView(views: [titleLabel, statusLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        brandView.translatesAutoresizingMaskIntoConstraints = false
        let headerStack = NSStackView(views: [brandView, titleStack])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 12

        let stack = NSStackView(views: [headerStack, fiveHourRow, weeklyRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            weeklyRow.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            modeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            modeButton.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            modeButton.widthAnchor.constraint(equalToConstant: 14),
            modeButton.heightAnchor.constraint(equalToConstant: 14),
            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            brandView.widthAnchor.constraint(equalToConstant: 38),
            brandView.heightAnchor.constraint(equalToConstant: 38),
            fiveHourRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            weeklyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            fiveHourRow.heightAnchor.constraint(equalToConstant: 54),
            weeklyRow.heightAnchor.constraint(equalToConstant: 54)
        ])

        update(.idle)
    }
}

@MainActor
final class CompactQuotaPanelView: NSView {
    var onModeToggle: (() -> Void)?

    private let modeButton = PanelModeToggleButton(targetMode: .full)
    private let fiveHourRow = CompactQuotaRowView()
    private let weeklyRow = CompactQuotaRowView()
    private let notApplicableLabel = NSTextField(labelWithString: "")

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(_ result: QuotaReadResult) {
        if case .notApplicable = result {
            fiveHourRow.isHidden = true
            weeklyRow.isHidden = true
            notApplicableLabel.isHidden = false
            notApplicableLabel.stringValue = "ChatGPT plan only"
            return
        }

        notApplicableLabel.isHidden = true
        fiveHourRow.isHidden = false
        weeklyRow.isHidden = false
        let rows = QuotaCompactPanelFormatter.rows(for: result)
        fiveHourRow.update(rows[0])
        weeklyRow.update(rows[1])
    }

    @objc private func toggleMode() {
        onModeToggle?()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.114, green: 0.118, blue: 0.133, alpha: 0.98).cgColor
        layer?.cornerRadius = 22
        layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.14).cgColor
        layer?.borderWidth = 1

        modeButton.onClick = { [weak self] in
            self?.toggleMode()
        }
        modeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modeButton)

        notApplicableLabel.font = .systemFont(ofSize: 12, weight: .medium)
        notApplicableLabel.textColor = NSColor(calibratedWhite: 0.78, alpha: 1)
        notApplicableLabel.lineBreakMode = .byTruncatingTail
        notApplicableLabel.isHidden = true

        let stack = NSStackView(views: [fiveHourRow, weeklyRow, notApplicableLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            modeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            modeButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            modeButton.widthAnchor.constraint(equalToConstant: 14),
            modeButton.heightAnchor.constraint(equalToConstant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: modeButton.leadingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            fiveHourRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            weeklyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            fiveHourRow.heightAnchor.constraint(equalToConstant: 28),
            weeklyRow.heightAnchor.constraint(equalToConstant: 28)
        ])

        update(.idle)
    }
}

@MainActor
private final class PanelGaugeMarkView: NSView {
    var weeklyRemainingPercent: Int? {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        StatusIconRenderer.drawGaugeMark(
            in: bounds.insetBy(dx: 2, dy: 2),
            primaryColor: .white,
            weeklyRemainingPercent: weeklyRemainingPercent
        )
    }
}

@MainActor
private final class PanelModeToggleButton: NSButton {
    var onClick: (() -> Void)?

    private let targetMode: QuotaPanelMode

    init(targetMode: QuotaPanelMode) {
        self.targetMode = targetMode
        super.init(frame: NSRect(x: 0, y: 0, width: 14, height: 14))
        isBordered = false
        title = ""
        imagePosition = .imageOnly
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        toolTip = targetMode == .full ? "크게 보기" : "작게 보기"
        setAccessibilityLabel(toolTip)
    }

    required init?(coder: NSCoder) {
        self.targetMode = .compact
        super.init(coder: coder)
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 14, height: 14)
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isHighlighted = false
        needsDisplay = true

        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            performClick(self)
        }
    }

    override func performClick(_ sender: Any?) {
        onClick?()
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let circleRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let fillAlpha: CGFloat = isHighlighted ? 0.78 : 1
        NSColor(calibratedWhite: 1.0, alpha: fillAlpha).setFill()
        NSBezierPath(ovalIn: circleRect).fill()

        NSColor(calibratedWhite: 0.0, alpha: 0.90).setFill()
        for path in trianglePaths() {
            path.fill()
        }
    }

    private func trianglePaths() -> [NSBezierPath] {
        switch targetMode {
        case .full:
            return [
                triangle(points: [
                    NSPoint(x: 3.2, y: 7.0),
                    NSPoint(x: 6.0, y: 4.4),
                    NSPoint(x: 6.0, y: 9.6)
                ]),
                triangle(points: [
                    NSPoint(x: 10.8, y: 7.0),
                    NSPoint(x: 8.0, y: 4.4),
                    NSPoint(x: 8.0, y: 9.6)
                ])
            ]
        case .compact:
            return [
                triangle(points: [
                    NSPoint(x: 5.9, y: 7.0),
                    NSPoint(x: 3.2, y: 4.4),
                    NSPoint(x: 3.2, y: 9.6)
                ]),
                triangle(points: [
                    NSPoint(x: 8.1, y: 7.0),
                    NSPoint(x: 10.8, y: 4.4),
                    NSPoint(x: 10.8, y: 9.6)
                ])
            ]
        }
    }

    private func triangle(points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: points[0])
        path.line(to: points[1])
        path.line(to: points[2])
        path.close()
        return path
    }
}

@MainActor
private final class FullQuotaRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let progressBar = QuotaProgressBarView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(_ reading: QuotaLimitReading) {
        titleLabel.stringValue = reading.kind.displayTitle
        percentLabel.stringValue = "\(reading.remainingPercent)%"
        detailLabel.stringValue = reading.detailText ?? "Remaining allowance"
        progressBar.percent = reading.remainingPercent
    }

    func updatePlaceholder(title: String) {
        titleLabel.stringValue = title
        percentLabel.stringValue = "--"
        detailLabel.stringValue = "Refresh usage from Codex"
        progressBar.percent = 0
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = NSColor(calibratedWhite: 0.90, alpha: 1)
        titleLabel.lineBreakMode = .byTruncatingTail

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        percentLabel.textColor = .white
        percentLabel.alignment = .right

        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        detailLabel.lineBreakMode = .byTruncatingTail

        let header = NSStackView(views: [titleLabel, percentLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        let stack = NSStackView(views: [header, progressBar, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progressBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            percentLabel.widthAnchor.constraint(equalToConstant: 56)
        ])
    }
}

@MainActor
private final class CompactQuotaRowView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let resetLabel = NSTextField(labelWithString: "")
    private let progressBar = QuotaProgressBarView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(_ row: QuotaCompactPanelRow) {
        titleLabel.stringValue = row.title
        percentLabel.stringValue = row.percentText
        resetLabel.stringValue = row.resetText
        progressBar.percent = row.progressPercent
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor(calibratedWhite: 0.90, alpha: 1)
        titleLabel.lineBreakMode = .byTruncatingTail

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        percentLabel.textColor = .white
        percentLabel.alignment = .right

        resetLabel.font = .systemFont(ofSize: 12, weight: .regular)
        resetLabel.textColor = NSColor(calibratedWhite: 0.78, alpha: 1)
        resetLabel.alignment = .right
        resetLabel.lineBreakMode = .byTruncatingTail

        [titleLabel, percentLabel, resetLabel, progressBar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -8),
            percentLabel.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            percentLabel.trailingAnchor.constraint(equalTo: resetLabel.leadingAnchor, constant: -7),
            resetLabel.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            resetLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            titleLabel.widthAnchor.constraint(equalToConstant: 44),
            percentLabel.widthAnchor.constraint(equalToConstant: 34)
        ])
    }
}

@MainActor
private final class QuotaProgressBarView: NSView {
    var percent: Int = 0 {
        didSet {
            percent = min(max(percent, 0), 100)
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackRect = bounds.insetBy(dx: 0, dy: 1)
        NSColor(calibratedWhite: 1.0, alpha: 0.12).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4).fill()

        guard percent > 0 else {
            return
        }

        let fillWidth = max(4, trackRect.width * CGFloat(percent) / 100)
        let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
        barColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4).fill()
    }

    private var barColor: NSColor {
        if percent >= 50 {
            return NSColor(calibratedRed: 0.10, green: 0.86, blue: 0.82, alpha: 1)
        }
        if percent >= 20 {
            return NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.25, alpha: 1)
        }
        return NSColor(calibratedRed: 0.95, green: 0.28, blue: 0.28, alpha: 1)
    }
}
