The FoundationModels framework provides access to Apple's on-device 3 billion parameter large language model. Here are all the core APIs and their usage.[1][2][3]

## Core APIs

### SystemLanguageModel
Represents the on-device text language model.[4][1]

```swift
import FoundationModels

// Check availability
guard SystemLanguageModel.default.isAvailable else {
    print("Apple Intelligence not available")
    return
}

// Granular availability check
let availability = SystemLanguageModel.default.availability
```

### LanguageModelSession
Creates a session for interacting with the model.[5][3]

```swift
// Basic session
let session = LanguageModelSession()

// Session with system instructions
let instructions = """
You are a helpful assistant. Keep responses concise.
"""
let session = LanguageModelSession(instructions: instructions)

// Basic text generation
let response = try await session.respond(to: "Explain Swift concurrency")
print(response.content)
```

### GenerationOptions
Controls how the model generates text.[6][4]

```swift
// Configure sampling and temperature
let seed = UInt64(Calendar.current.component(.dayOfYear, from: .now))
let sampling = GenerationOptions.SamplingMode.random(top: 10, seed: seed)
let options = GenerationOptions(sampling: sampling, temperature: 0.7)

let response = try await session.respond(to: "Write a haiku", options: options)
```

## Guided Generation

### @Generable Macro
Generates structured Swift data types with strong guarantees.[7][6]

```swift
@Generable
struct Recipe {
    var name: String
    var ingredients: [String]
    var steps: [String]
    var prepTime: Int
}

let session = LanguageModelSession()
let recipe: Recipe = try await session.respond(
    to: "Create a recipe for chocolate cake"
)
```

### @Guide Macro
Provides natural language descriptions for properties.[6]

```swift
@Generable
struct Event {
    @Guide("The event title")
    var title: String
    
    @Guide("ISO8601 formatted date")
    var date: String
    
    @Guide("Location name or address")
    var location: String
}
```

### Dynamic Schemas
Create schemas at runtime without compile-time types.[7]

```swift
// Define schema programmatically
let schema = DynamicSchema(
    properties: [
        "title": .string,
        "rating": .number,
        "tags": .array(.string)
    ]
)

let response: GeneratedContent = try await session.respond(
    to: "Analyze this movie",
    schema: schema
)

// Access with property names
let title = response["title"] as? String
```

## Streaming APIs

### streamResponse
Get real-time token generation for responsive UIs.[5][6]

```swift
let stream = try await session.streamResponse(to: "Write a story")

for try await chunk in stream {
    print(chunk.content, terminator: "")
}
```

## Tool Calling

### Tool Protocol
Let the model call custom functions autonomously.[6][7]

```swift
struct WeatherTool: Tool {
    static let description = "Gets current weather for a location"
    
    struct Input: Codable {
        let location: String
    }
    
    struct Output: Codable {
        let temperature: Double
        let condition: String
    }
    
    func callAsFunction(_ input: Input) async throws -> Output {
        // Call weather API
        return Output(temperature: 72.0, condition: "Sunny")
    }
}

// Use tool in session
let tools = [WeatherTool()]
let response = try await session.respond(
    to: "What's the weather in San Francisco?",
    tools: tools
)
```

## Multi-turn Conversations

### Transcript
Maintain conversation history.[3][6]

```swift
var transcript = Transcript()

// Add user message
transcript.append(message: "What's Swift?", role: .user)

// Get response and add to transcript
let response1 = try await session.respond(to: transcript)
transcript.append(message: response1.content, role: .assistant)

// Continue conversation
transcript.append(message: "Give me an example", role: .user)
let response2 = try await session.respond(to: transcript)
```

## Feedback

### LanguageModelFeedback
Provide feedback on model responses.[3]

```swift
let feedback = LanguageModelFeedback(
    response: response,
    rating: .positive
)
```

## Requirements

- iOS 26.0+, iPadOS 26.0+, macOS Sequoia 26.0+, or visionOS 3.0+[2][8]
- Xcode 16+[6]
- Apple Intelligence enabled on compatible devices[1]
- All processing happens on-device for privacy[2][6]

[1](https://developer.apple.com/documentation/FoundationModels)
[2](https://www.apple.com/in/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)
[3](https://stackoverflow.com/questions/29500227/getting-error-no-such-module-using-xcode-but-the-framework-is-there)
[4](https://swiftwithmajid.com/2025/08/19/building-ai-features-using-foundation-models/)
[5](https://www.createwithswift.com/exploring-the-foundation-models-framework/)
[6](https://developer.apple.com/videos/play/wwdc2025/286/)
[7](https://developer.apple.com/videos/play/wwdc2025/301/)
[8](https://pub.dev/documentation/foundation_models_framework/latest/)
[9](https://developer.apple.com/documentation/technologyoverviews/foundation-models?changes=_8_6)
[10](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
[11](https://developer.apple.com/videos/play/meet-with-apple/205/)