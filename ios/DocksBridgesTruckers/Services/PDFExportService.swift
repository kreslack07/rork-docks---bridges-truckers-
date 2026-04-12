import UIKit
import PDFKit

nonisolated struct PDFExportService {

    static func generateReport(
        truckProfile: TruckProfile,
        hazards: [Hazard],
        docks: [Dock],
        hazardStatusProvider: @Sendable (Hazard) -> HazardStatus
    ) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            var yPosition: CGFloat = 0

            func startNewPage() {
                context.beginPage()
                yPosition = margin
            }

            func ensureSpace(_ needed: CGFloat) {
                if yPosition + needed > pageHeight - margin {
                    startNewPage()
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .black, x: CGFloat = margin, maxWidth: CGFloat? = nil) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let w = maxWidth ?? contentWidth
                let boundingRect = (text as NSString).boundingRect(
                    with: CGSize(width: w, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                ensureSpace(boundingRect.height + 4)
                (text as NSString).draw(in: CGRect(x: x, y: yPosition, width: w, height: boundingRect.height), withAttributes: attrs)
                yPosition += boundingRect.height + 4
            }

            func drawDivider() {
                ensureSpace(16)
                yPosition += 6
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPosition))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
                UIColor.systemGray4.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                yPosition += 10
            }

            func drawPill(_ text: String, color: UIColor, x: CGFloat) {
                let font = UIFont.systemFont(ofSize: 9, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                let textSize = (text as NSString).size(withAttributes: attrs)
                let pillWidth = textSize.width + 14
                let pillHeight = textSize.height + 6
                let pillRect = CGRect(x: x, y: yPosition, width: pillWidth, height: pillHeight)
                let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillHeight / 2)
                color.setFill()
                pillPath.fill()
                (text as NSString).draw(
                    at: CGPoint(x: x + 7, y: yPosition + 3),
                    withAttributes: attrs
                )
            }

            // --- Page 1: Header + Truck Profile ---
            startNewPage()

            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let headingFont = UIFont.systemFont(ofSize: 16, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let bodyBoldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let smallFont = UIFont.systemFont(ofSize: 9, weight: .regular)

            let accentColor = UIColor(red: 0.95, green: 0.52, blue: 0.07, alpha: 1)

            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 80)
            let navyColor = UIColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1)
            navyColor.setFill()
            UIBezierPath(rect: headerRect).fill()

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.white]
            ("Docks & Bridges Truckers" as NSString).draw(at: CGPoint(x: margin, y: 22), withAttributes: titleAttrs)

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let dateStr = "Report generated: \(dateFormatter.string(from: Date()))"
            let dateAttrs: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: UIColor.white.withAlphaComponent(0.7)]
            (dateStr as NSString).draw(at: CGPoint(x: margin, y: 52), withAttributes: dateAttrs)

            yPosition = 96

            // Truck Profile Section
            drawText("TRUCK PROFILE", font: headingFont, color: accentColor)
            yPosition += 4

            let profileBgRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 100)
            UIColor.systemGray6.setFill()
            UIBezierPath(roundedRect: profileBgRect, cornerRadius: 8).fill()

            let profileX = margin + 14
            let col2X = margin + contentWidth / 2
            let profileY = yPosition + 12

            yPosition = profileY
            let nameDisplay = truckProfile.name.isEmpty ? "Not Set" : truckProfile.name
            drawText("Driver / Truck:  \(nameDisplay)", font: bodyBoldFont, x: profileX, maxWidth: contentWidth - 28)
            drawText("Vehicle Type:  \(truckProfile.type.label)", font: bodyFont, x: profileX, maxWidth: contentWidth / 2 - 20)

            yPosition = profileY
            drawText("Height:  \(String(format: "%.1f", truckProfile.height)) m", font: bodyFont, x: col2X, maxWidth: contentWidth / 2 - 20)
            drawText("Weight:  \(String(format: "%.1f", truckProfile.weight)) t", font: bodyFont, x: col2X, maxWidth: contentWidth / 2 - 20)
            drawText("Width:  \(String(format: "%.1f", truckProfile.width)) m", font: bodyFont, x: col2X, maxWidth: contentWidth / 2 - 20)
            drawText("Length:  \(String(format: "%.1f", truckProfile.length)) m", font: bodyFont, x: col2X, maxWidth: contentWidth / 2 - 20)

            let plateDisplay = truckProfile.plateNumber.isEmpty ? "Not Set" : truckProfile.plateNumber
            drawText("Plate:  \(plateDisplay)", font: bodyFont, x: profileX, maxWidth: contentWidth / 2 - 20)

            yPosition = profileBgRect.maxY + 8

            // Summary counts
            let blocked = hazards.filter { hazardStatusProvider($0) == .blocked }
            let tight = hazards.filter { hazardStatusProvider($0) == .tight }
            let safe = hazards.filter { hazardStatusProvider($0) == .safe }

            drawDivider()
            drawText("HAZARD SUMMARY", font: headingFont, color: accentColor)
            yPosition += 4

            let summaryY = yPosition
            let colWidth: CGFloat = contentWidth / 3

            func drawSummaryBox(title: String, count: Int, color: UIColor, xOffset: CGFloat) {
                let boxRect = CGRect(x: margin + xOffset, y: summaryY, width: colWidth - 8, height: 52)
                UIColor.systemGray6.setFill()
                UIBezierPath(roundedRect: boxRect, cornerRadius: 8).fill()

                let countAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: color]
                let countStr = "\(count)"
                let countSize = (countStr as NSString).size(withAttributes: countAttrs)
                (countStr as NSString).draw(at: CGPoint(x: boxRect.midX - countSize.width / 2, y: summaryY + 6), withAttributes: countAttrs)

                let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .semibold), .foregroundColor: color]
                let labelSize = (title as NSString).size(withAttributes: labelAttrs)
                (title as NSString).draw(at: CGPoint(x: boxRect.midX - labelSize.width / 2, y: summaryY + 32), withAttributes: labelAttrs)
            }

            drawSummaryBox(title: "BLOCKED", count: blocked.count, color: .systemRed, xOffset: 0)
            drawSummaryBox(title: "TIGHT", count: tight.count, color: accentColor, xOffset: colWidth)
            drawSummaryBox(title: "CLEAR", count: safe.count, color: .systemGreen, xOffset: colWidth * 2)

            yPosition = summaryY + 64

            // Hazards List
            drawDivider()
            drawText("HAZARDS (\(hazards.count))", font: headingFont, color: accentColor)
            yPosition += 2

            for hazard in hazards {
                ensureSpace(48)
                let status = hazardStatusProvider(hazard)
                let statusColor: UIColor = switch status {
                case .blocked: .systemRed
                case .tight: accentColor
                case .safe: .systemGreen
                }

                let rowBg = CGRect(x: margin, y: yPosition, width: contentWidth, height: 40)
                UIColor.systemGray6.setFill()
                UIBezierPath(roundedRect: rowBg, cornerRadius: 6).fill()

                drawPill(status.label, color: statusColor, x: margin + 8)

                let nameX = margin + 80
                let nameAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.label]
                (hazard.name as NSString).draw(at: CGPoint(x: nameX, y: yPosition + 4), withAttributes: nameAttrs)

                var detail = "\(hazard.type.label) · \(hazard.road), \(hazard.city)"
                if hazard.type == .weight_limit, let wl = hazard.weightLimit {
                    detail += " · \(String(format: "%.0f", wl))t limit"
                } else {
                    detail += " · \(String(format: "%.1f", hazard.clearanceHeight))m clearance"
                }
                let detailAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.secondaryLabel]
                (detail as NSString).draw(at: CGPoint(x: nameX, y: yPosition + 20), withAttributes: detailAttrs)

                yPosition += 46
            }

            // Docks List
            drawDivider()
            drawText("DOCKS (\(docks.count))", font: headingFont, color: accentColor)
            yPosition += 2

            for dock in docks {
                ensureSpace(48)

                let rowBg = CGRect(x: margin, y: yPosition, width: contentWidth, height: 40)
                UIColor.systemGray6.setFill()
                UIBezierPath(roundedRect: rowBg, cornerRadius: 6).fill()

                let catAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: UIColor.white]
                let catText = dock.businessCategory.label.uppercased()
                let catSize = (catText as NSString).size(withAttributes: catAttrs)
                let catPillW = min(catSize.width + 14, 120)
                let catPillRect = CGRect(x: margin + 8, y: yPosition + 12, width: catPillW, height: catSize.height + 6)
                let catPath = UIBezierPath(roundedRect: catPillRect, cornerRadius: (catSize.height + 6) / 2)
                UIColor.systemBlue.setFill()
                catPath.fill()
                (catText as NSString).draw(at: CGPoint(x: margin + 15, y: yPosition + 15), withAttributes: catAttrs)

                let dNameX = margin + catPillW + 20
                let dNameAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.label]
                (dock.name as NSString).draw(at: CGPoint(x: dNameX, y: yPosition + 4), withAttributes: dNameAttrs)

                let dDetail = "\(dock.address), \(dock.city) · \(dock.dockType.label)"
                let dDetailAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.secondaryLabel]
                (dDetail as NSString).draw(at: CGPoint(x: dNameX, y: yPosition + 20), withAttributes: dDetailAttrs)

                yPosition += 46
            }

            // Footer
            ensureSpace(40)
            yPosition += 12
            drawDivider()
            drawText("Generated by Docks & Bridges Truckers app · Data for reference only · Always verify signs on approach", font: smallFont, color: .secondaryLabel)
        }

        return data
    }
}
