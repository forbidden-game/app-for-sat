import XCTest
@testable import StudentCore

final class MathMarkupTests: XCTestCase {
    func testParsePlainText() {
        let parser = MathMarkupParser()
        let doc = parser.parse("Hello world.")
        XCTAssertEqual(doc.segments, [.text("Hello world.")])
        XCTAssertFalse(doc.requiresMathRendering)
        XCTAssertEqual(doc.normalizedText, "Hello world.")
        XCTAssertEqual(doc.plainText, "Hello world.")
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    func testParseInlineMath() {
        let parser = MathMarkupParser()
        let doc = parser.parse("Solve $x+1$ now.")
        XCTAssertEqual(doc.segments.count, 3)
        XCTAssertEqual(doc.segments[0], .text("Solve "))
        XCTAssertEqual(doc.segments[1], .inlineMath("x+1"))
        XCTAssertEqual(doc.segments[2], .text(" now."))
        XCTAssertTrue(doc.requiresMathRendering)
        XCTAssertEqual(doc.normalizedText, "Solve $x+1$ now.")
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    func testParseInlineMathWithParenthesesDelimiters() {
        let parser = MathMarkupParser()
        let doc = parser.parse("Solve \\(x+1\\) now.")
        XCTAssertEqual(doc.segments.count, 3)
        XCTAssertEqual(doc.segments[0], .text("Solve "))
        XCTAssertEqual(doc.segments[1], .inlineMath("x+1"))
        XCTAssertEqual(doc.segments[2], .text(" now."))
        XCTAssertTrue(doc.requiresMathRendering)
        XCTAssertEqual(doc.normalizedText, "Solve $x+1$ now.")
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    func testParseBlockMathWithBrackets() {
        let parser = MathMarkupParser()
        let doc = parser.parse("Given \\[x^2\\] is positive.")
        XCTAssertEqual(doc.segments.count, 3)
        XCTAssertEqual(doc.segments[1], .blockMath("x^2"))
        XCTAssertEqual(doc.normalizedText, "Given $$x^2$$ is positive.")
    }

    func testNormalizeAlignEnvironment() {
        let parser = MathMarkupParser()
        let input = "\\begin{align*}a=b\\\\c=d\\end{align*}"
        let doc = parser.parse(input)
        XCTAssertEqual(doc.segments.count, 1)
        XCTAssertEqual(doc.segments[0], .blockMath("\\begin{aligned}a=b\\\\c=d\\end{aligned}"))
        XCTAssertEqual(doc.normalizedText, "$$\\begin{aligned}a=b\\\\c=d\\end{aligned}$$")
    }

    func testUnbalancedDelimiterWarns() {
        let parser = MathMarkupParser()
        let input = "Cost is $5"
        let doc = parser.parse(input)
        XCTAssertEqual(doc.segments, [.text(input)])
        XCTAssertFalse(doc.requiresMathRendering)
        XCTAssertTrue(doc.warnings.contains(.unbalancedDelimiters))
    }

    func testInvalidEnvironmentWarns() {
        let parser = MathMarkupParser()
        let input = "\\begin{foo}x\\end{foo}"
        let doc = parser.parse(input)
        XCTAssertEqual(doc.segments, [.text(input)])
        XCTAssertTrue(doc.warnings.contains(.invalidEnvironment("foo")))
    }

    func testInvalidEnvironmentStillParsesInlineMath() {
        let parser = MathMarkupParser()
        let input = "\\begin{center}Area is $x^2$.\\end{center}"
        let doc = parser.parse(input)
        XCTAssertTrue(doc.requiresMathRendering)
        XCTAssertTrue(doc.normalizedText.contains("$x^2$"))
        XCTAssertTrue(doc.warnings.contains(.invalidEnvironment("center")))
    }

    func testPlainTextExtractsMathContent() {
        let parser = MathMarkupParser()
        let doc = parser.parse("Area is $\\pi r^2$.")
        XCTAssertTrue(doc.plainText.contains("Area is"))
        XCTAssertTrue(doc.plainText.contains("pi r^2"))
    }

    func testPlainTextKeepsMarkdownCharacters() {
        let parser = MathMarkupParser()
        let input = "a_b * c"
        let doc = parser.parse(input)
        XCTAssertFalse(doc.requiresMathRendering)
        XCTAssertEqual(doc.plainText, input)
        XCTAssertEqual(doc.normalizedText, input)
    }
}
