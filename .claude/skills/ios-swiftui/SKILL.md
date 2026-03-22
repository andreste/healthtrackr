---
name: ios-swiftui
description: Build production-grade iOS apps with Swift and SwiftUI. Use this skill whenever the user writes iOS code, creates SwiftUI views, builds ViewModels, handles networking, or asks for Swift best practices. Triggers on any mention of "iOS", "SwiftUI", "Swift", ".swift", ".swiftui", or when building mobile apps for Apple platforms. Always apply MVVM architecture, async/await patterns, proper error handling, and accessibility standards to generated code.
---

# iOS SwiftUI Skill

Build production-grade iOS applications with proper architecture, performance optimization, and best practices.

## Core Rules

### MVVM Architecture (Mandatory)
- **ViewModels** handle all business logic, state management, and data fetching
- **Views** are presentation-only; zero business logic allowed in SwiftUI views
- **Models** are `Codable` structs with computed properties only
- Never pass view state directly between views; use `@StateObject` + `@ObservedObject`
- Views should be stateless presentation layers; `@State` only for UI-transient state (animations, sheet visibility)

### State Management Rules

| Type | Use Case | Example |
|------|----------|---------|
| `@State` | UI transient state only | `@State var isLoading = false`, `@State var selectedTab = 0` |
| `@StateObject` | ViewModel in parent view | Create once, pass down as `@ObservedObject` |
| `@ObservedObject` | Receive ViewModel from parent | `@ObservedObject var viewModel: MyViewModel` |
| `@EnvironmentObject` | App-wide singletons | `AuthManager`, `NetworkManager` |
| `@Published` | Observable ViewModel properties | Data that should trigger view updates |
| `@FocusState` | Keyboard focus | Keyboard management without TextField hacks |

**Anti-pattern**: Never use `@State` for fetched data, persistent values, or view state that lives beyond the current view.

### Dependency Injection
- Inject dependencies via environment objects or initializers; never hardcode
- Use `@EnvironmentObject` for app-wide singletons (AuthManager, NetworkManager)
- Pass ViewModels as `@StateObject` in parent views, inject as `@ObservedObject` in children
- Avoid nested dependency chains; max 2 levels deep

## SwiftUI View Best Practices

### View Composition & Structure
- Each view should have **one primary responsibility**
- Extract subviews into separate structs once they exceed 20 lines
- Use helper computed properties (`var headerView: some View`) for inline reusable sections
- **Naming conventions**:
  - Root views: `ContentView`
  - Feature screens: `ProfileView`, `SettingsView`
  - Reusable components: `UserRowView`, `CustomButtonView`
  - Helper properties: `isEmpty`, `isFormValid`, `emptyStateView`

### View Modifiers Chaining
```swift
// ✅ GOOD: Layout → Appearance → Interaction → Animation
Button("Submit") { action() }
    .frame(maxWidth: .infinity)      // Layout
    .background(.blue)               // Appearance
    .foregroundColor(.white)         // Appearance
    .disabled(!isFormValid)           // Interaction
    .opacity(isEnabled ? 1 : 0.5)    // Appearance
    .animation(.easeInOut, value: isFormValid)  // Animation
```

Create reusable modifier extensions:
```swift
extension View {
    func customPrimaryButton() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(.blue)
            .cornerRadius(8)
    }
}
```

### Performance Rules
- Use `@ViewBuilder` to avoid unnecessary view creation
- Wrap computed properties returning views in `@ViewBuilder`
- Use `.id()` on ForEach items with non-stable identifiers (never use index alone)
- Minimize view body complexity; extract heavy computations to ViewModel
- Use `.equatable()` to prevent unnecessary redraws of child views
- For complex lists: prefer `LazyVStack` with `ScrollView` over `List` when performance matters

```swift
// ✅ GOOD: Use LazyVStack for performance-critical lists
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(items, id: \.id) { item in
            ItemRowView(item: item)
        }
    }
}

// ⚠️ Use List only when standard behavior is needed
List(items, id: \.id) { item in
    ItemRowView(item: item)
}
```

## Data & Networking

### Models & Codable
```swift
struct User: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "full_name"  // Map API field name
        case email = "user_email"
    }
}
```

**Rules**:
- All models are `struct`, `Codable`, `Hashable`
- Add explicit `Identifiable` conformance with `id` property (never use implicit hash)
- Use `CodingKeys` for API-to-model property name mismatches
- Use `@Published` properties in ViewModels for Observable data
- Encode/decode dates with `ISO8601DateFormatter` unless API specifies otherwise

### Networking (async/await only)
```swift
class APIService {
    func fetchUsers() async throws -> [User] {
        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode([User].self, from: data)
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }
}
```

**Rules**:
- Use `async/await` exclusively; no completion handlers or Combine
- All network code in ViewModels or dedicated NetworkManager
- Wrap network calls in `Task { }` in views (only in `.onAppear`, `.onChange`, button actions)
- Always handle errors explicitly; never silently fail
- Set timeout: `.timeoutInterval = 30`
- Add request logging in debug builds only

### Data Caching Pattern
```swift
class UserViewModel: ObservableObject {
    @Published var users: [User]? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchUsers() async {
        // Already loaded, don't refetch
        if users != nil { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            users = try await apiService.fetchUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Error Handling

### Custom Error Types
```swift
enum APIError: LocalizedError {
    case invalidResponse
    case decodingFailed(String)
    case networkError(URLError)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        case .decodingFailed(let details):
            return "Failed to parse data: \(details)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "The URL was invalid."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidResponse:
            return "HTTP status code was outside 200-299 range"
        case .decodingFailed(let details):
            return "JSON structure doesn't match expected model: \(details)"
        default:
            return nil
        }
    }
}
```

### Error Display in Views
```swift
struct ContentView: View {
    @ObservedObject var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
            // Main content
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("Retry") { Task { await viewModel.retryLastAction() } }
            Button("Dismiss") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}
```

**Rules**:
- Create custom error enum with user-friendly `errorDescription`
- Include `.failureReason` for debugging context
- Store errors in ViewModel as `@Published var errorMessage: String?`
- Display via `.alert()` or custom error banner view
- Always provide recovery action (retry, dismiss, navigate)
- Never use `print()` for errors; use `os_log` in production

## Common Patterns

### List Pattern with Row Extraction
```swift
struct UserListView: View {
    @ObservedObject var viewModel: UserListViewModel
    
    var body: some View {
        List(viewModel.users) { user in
            UserRowView(user: user)
                .onTapGesture { viewModel.selectUser(user) }
        }
        .task { await viewModel.fetchUsers() }
    }
}

struct UserRowView: View {
    let user: User
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(user.name).font(.headline)
                Text(user.email).font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
    }
}
```

### Sheet/Navigation Pattern
```swift
struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                Button("Show Details") {
                    viewModel.isShowingDetail = true
                }
            }
            .sheet(isPresented: $viewModel.isShowingDetail) {
                DetailView(viewModel: viewModel.detailViewModel)
            }
        }
    }
}
```

**Rule**: Store sheet/navigation state in ViewModel as `@Published var isShowingDetail = false`, bind views to it.

### Form Pattern
```swift
struct EditView: View {
    @ObservedObject var viewModel: EditViewModel
    
    var body: some View {
        Form {
            Section("User Information") {
                TextField("Name", text: $viewModel.name)
                TextField("Email", text: $viewModel.email)
            }
            
            Section {
                Button("Save") {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.isFormValid)
            }
        }
    }
}
```

**Rule**: Bind form fields directly to ViewModel `@Published` properties with `$` binding.

### Loading State Pattern
```swift
enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
}

class MyViewModel: ObservableObject {
    @Published var state: LoadingState<[Item]> = .idle
    
    func fetchItems() async {
        state = .loading
        do {
            let items = try await apiService.fetchItems()
            state = .success(items)
        } catch {
            state = .failure(error)
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel = MyViewModel()
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
            case .success(let items):
                List(items) { item in
                    ItemRow(item: item)
                }
            case .failure(let error):
                ErrorView(error: error, retry: {
                    Task { await viewModel.fetchItems() }
                })
            }
        }
        .task { await viewModel.fetchItems() }
    }
}
```

## Code Style & Naming

### Naming Conventions
- **Views**: `ContentView`, `ProfileView`, `SettingsSheet`
- **ViewModels**: `ProfileViewModel`, `ListViewModel` (always suffix with ViewModel)
- **Services**: `AuthService`, `APIService`, `LocationService`
- **Boolean properties**: `isLoading`, `isVisible`, `hasError`, `canDelete`
- **Functions**: `fetchUsers()`, `deleteItem(id:)`, verb-first
- **Boolean-returning functions**: `shouldShowButton()` not `getShowButton()`

### Formatting
- Max line length: 100 characters
- Indent 2 spaces (Swift standard)
- Use meaningful variable names; no single-letter vars except in loops
- Comments above code blocks, not inline
- Use MARK comments for section organization:
  ```swift
  // MARK: - View
  
  // MARK: - ViewModel
  ```

## File Organization

```
ProjectName/
├── App/
│   ├── ProjectNameApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── User.swift
│   ├── Post.swift
│   └── APIModels.swift
├── ViewModels/
│   ├── ContentViewModel.swift
│   ├── ProfileViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── Screens/
│   │   ├── ProfileView.swift
│   │   └── SettingsView.swift
│   └── Components/
│       ├── UserRowView.swift
│       └── CustomButton.swift
├── Services/
│   ├── APIService.swift
│   ├── AuthService.swift
│   └── LocalStorageService.swift
└── Utilities/
    ├── Extensions.swift
    ├── Constants.swift
    └── Helpers.swift
```

## SwiftUI-Specific Gotchas

### Navigation APIs
- **Deprecated**: `NavigationView` with `NavigationLink` (iOS 15 and earlier)
- **Modern**: `NavigationStack` (iOS 16+) with `.navigationDestination()`
- **Fallback**: For iOS 15 support, use `NavigationView` but plan deprecation

### List Performance
- **Use `LazyVStack` + `ScrollView`** for complex content (images, nested views)
- **Use `List`** for simple rows, when you need built-in styling and pull-to-refresh
- **Never put heavy computations** in list cell bodies

### Modifier Order Matters
```swift
// Different results:
Text("Hello")
    .padding()
    .background(.blue)
// vs
Text("Hello")
    .background(.blue)
    .padding()
```

The first adds padding inside the blue background; the second adds padding outside.

### ForEach with IDs
```swift
// ✅ GOOD: Always provide stable ID
ForEach(items, id: \.id) { item in
    ItemRow(item: item)
}

// ❌ BAD: Never rely on index
ForEach(items.indices, id: \.self) { index in
    ItemRow(item: items[index])
}
```

### GeometryReader Performance
- Use sparingly; causes layout calculations
- **Better alternatives**:
  - `.frame(maxWidth: .infinity)` for full width
  - `@Environment(\.safeAreaInsets)` for safe area
  - `@ViewBuilder` for conditional content

### Main Thread Safety
- `@Published` changes are **already main-thread safe**
- No need for `DispatchQueue.main.async` when updating `@Published` properties

## Accessibility (A11y)

### Essential Requirements
- Add `.accessibilityLabel()` to all interactive elements without visible text
- Use `.accessibilityHint()` for complex interactions
- Add `.accessibilityValue()` to dynamic content (progress, counters)
- Use `.accessibilityElement(children: .combine)` to group related elements
- Maintain color contrast ratio **4.5:1 minimum** for text

### Example
```swift
Button(action: { deleteItem() }) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete item")
.accessibilityHint("Removes this item from the list permanently")
```

## Testing & Previews

### Preview Setup
```swift
#Preview {
    ContentView()
}

#Preview("Empty State") {
    ContentView(viewModel: .empty)
}

#Preview("Loading") {
    ContentView(viewModel: .loading)
}

#Preview("Error") {
    ContentView(viewModel: .error)
}
```

**Rules**:
- Always include previews
- Test multiple states: empty, loading, error, success
- Never use real network calls in previews; mock data only
- Use preview containers for dependency injection

## Anti-Patterns to Avoid

❌ **DO NOT:**
- Put network calls directly in view body
- Use `@State` for persistent data or fetched content
- Chain `@Binding` more than 1 level deep; use ViewModels instead
- Force-unwrap optionals; use `guard` or `if let`
- Create `@StateObject` inside child views
- Use `AnyView` except for type erasure in extensions
- Ignore errors silently; always handle explicitly
- Store ViewModels manually in AppDelegate or globals
- Mix Combine and async/await in same project
- Create monolithic views >200 lines; extract subviews

## Deployment Target Compatibility

- Target **iOS 14+ minimum** (unless specified otherwise)
- Use `@available(iOS 15, *)` for newer APIs
- Provide graceful fallbacks for older OS features
- Document any iOS-version-specific behavior in comments

## Quick Checklist for Generated Code

- [ ] MVVM architecture with separate Views, ViewModels, Models
- [ ] `@Published` for observable ViewModel properties
- [ ] No network calls in view bodies
- [ ] ViewModels use `async/await` (not Combine)
- [ ] Custom error enum with user-friendly messages
- [ ] Views extracted when >20 lines
- [ ] List cells extracted to separate view components
- [ ] `.task()` for onAppear network fetching
- [ ] `@StateObject` for ViewModels in parent, `@ObservedObject` in children
- [ ] Proper spacing and alignment (not relying on magic numbers)
- [ ] Accessibility labels on interactive elements
- [ ] Previews included with multiple states
- [ ] No force-unwraps
- [ ] Error handling with user feedback
- [ ] Proper file organization per project structure
