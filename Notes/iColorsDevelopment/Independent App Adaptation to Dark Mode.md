# Independent App Adaptation to Dark Mode

   > About Me: Daytime iOS developer in China + after-hours indie developer, planning to deliver in-depth tech articles + indie-dev tricks.
   >
   > My Indie App Development: [iColors - Color palette muse](https://link.juejin.cn/?target=https%3A%2F%2Fapps.apple.com%2Fapp%2Fid6448422065)
   >

Adapting an independent app to dark mode is a task that can greatly enhance user experience. In this article, I will take my own indie app "iColors" as an example to explain the steps of adapting to dark mode in detail.

Adapting to dark mode is not difficult. Just follow the steps in this article, and you'll do just fine! If you find this interesting or useful, please like and save it. If you find it extremely helpful, feel free to download my app from the App Store and leave a five-star review, haha!

Actual effect demonstration:

> Cause I finished Chinese version first, so illustrations in the article may contains Chinese. Sorry about that.

| Light Mode                               | Dark Mode                                |
| :--------------------------------------- | :--------------------------------------- |
| ![](../../backups/iColorsDarkmode/0.png) | ![](../../backups/iColorsDarkmode/1.png) |

   

# 🤔 Why Adapt to Dark Mode

Since its introduction, dark mode consideration has become imperative for all apps.

Without adapting to dark mode, it becomes nearly impossible for the app to be used normally due to various UI display issues. In fact, the user base for dark mode is not insignificant. For example, when the first version of iColors was launched, it did not support dark mode and immediately faced complaints from dark mode users, haha.

Therefore, to avoid losing users or attracting negative reviews because an app doesn't support dark mode, it's best to adapt, even if the first version isn't perfect.



# 📱 Step Zero: Learn How to Debug Dark Mode

Before you begin, you need to learn how to test dark mode so that you can debug and adapt conveniently.

### Debugging in Canvas

The most straightforward way is to use the button below to let Preview render Dark Mode:

<img src="../../backups/iColorsDarkmode/2_1.png" style="zoom: 50%;" />

But in fact, Canvas has provided us with an even more ingenious way of adapting to dark mode:

<img src="../../backups/iColorsDarkmode/2_2.png" style="zoom: 80%;" />

After selecting it, you can directly see the comparison chart, the effect is as follows, which is very convenient. This is my most commonly used debugging method now, making full use of SwiftUI features to see the actual effects as I write.

<img src="../../backups/iColorsDarkmode/2_3.png" style="zoom: 70%;" />

### Debugging in the Simulator

All you need to do is select Features on the Simulator's menu bar and choose Toggle Appearance from the dropdown menu for easy switching.

<img src="../../backups/iColorsDarkmode/2_4.png" style="zoom: 80%;" />

### Debugging on Real Devices

You can switch in settings, which I'm sure everyone is familiar with. However, switching processes and speeds are not as fast and convenient as those in the simulator and Preview, so I generally do not use a real device for debugging when adapting dark mode.

<img src="../../backups/iColorsDarkmode/2_5.png" style="zoom: 30%;" />



# 🎨 Step One: Color Adaptation to Dark Mode

### Color Configuration

First and foremost, we need to adapt colors. For example, the dark mode might use white for backgrounds and black for titles while the light mode does the opposite.

The logic is easy to understand, so how can we implement it? There are several methods available, but I find the most reasonable approach is to directly add Color Sets in the Assets directory. The specific steps are as follows:

1. Select Assets, click "+" or right-click and you can add a Color Set.
2. The system will create a default color which you can rename.
3. Modify the Any Appearance & Dark colors according to your needs to represent the colors used in light and dark mode respectively.

![](../../backups/iColorsDarkmode/2.png)

As shown above, this is a color set named ListBackground that I set up, mainly used for the list background color. In light mode, the list will use a color close to white, and in dark mode, it will use a background color close to black.

### The Three Modes of Appearances

It's important to note that there are two default color options called Any Appearance and Dark. Why not Light and Dark? Because in addition to Light and Dark, there is a case for devices that do not support dark mode!

![](../../backups/iColorsDarkmode/3.png)

Open the Inspectors panel, find Appearances and you'll see the nuances since there are actually three modes available:

- None: Only one color option for any case.
- Any, Dark: Two color options, Dark represents the color for dark mode, Any represents other cases.
- Any, Light, Dark: Three color options, Light and Dark represent light and dark modes respectively, Any represents the remaining cases, i.e., the color used on devices that do not support dark mode!

### Using Colors

To easily use a predefined Color Set that supports dark mode, we can add an extension to the Color as follows:

```swift
extension Color {
  static let ListBackground = Color("ListBackground")
}
```

This way, we can use the defined background color ListBackground as shown below:

```swift
SomeView()
   .background(Color.ListBackground)
```



## 🌄 Step Two: Image Adaptation to Dark Mode

Similar to Color Sets, images can be adapted to dark mode in the same way.

1. Select Assets, click "+" or right-click, and you can add an Image Set.
2. The system will default create an image set which you can rename.
3. The default image has only one style. We need to open the Inspectors panel, find Appearances and change it to "Any, Dark".

![](../../backups/iColorsDarkmode/4.png)

Now, we can upload two images as indicated. For example, put a sun icon in Any for light mode display; put a moon icon in Dark for dark mode display:

![](../../backups/iColorsDarkmode/5.png)

When using the image in code, you don't need to consider the light or dark status, just use it like a normal image, very simple:

```swift
Image("name")
```

   

## ⚙️ Step Three: Dark Mode Selection Page

Within iColors, I've created a separate page that allows users to manually select between a light appearance, a dark appearance, or to follow the system settings. This feature is visually represented as follows:

<img src="../../backups/iColorsDarkmode/6.png" alt="Dark Mode Selection Page" title="Dark Mode Selection Page" style="zoom:50%;" /> 

Of course, this step isn't mandatory. If we adhere to the philosophy of simplicity for independent apps, it's completely acceptable to omit this settings page. Essentially, this defaults to allowing the user to choose the system appearance setting. Whatever the system appearance is, the app retrieves it and uses it accordingly.

However, I believe adding a settings page offers more convenience and flexibility without incurring a significant development cost; hence, I ultimately included it.

To implement this, we must first define an enum type representing different appearance scenarios:

```swift
enum SchemeType: Int, Identifiable, CaseIterable {
   var id: Self { self }
   case light
   case dark
   case system

   /// Retrieves the corresponding ColorScheme for setting
   var SystemColorScheme: ColorScheme? {
       switch self {
       case .light:
         	return .light
       case .dark:
         	return .dark
       case .system:
         	// Returning nil means no special handling
         	return nil
       }
   }
}
```

We need to utilize `SystemColorScheme` to map the system's appearance type to our custom enum type. `SchemeType` is our custom designation, while `ColorScheme` is the one provided by the system.

`SchemeType.system` represents "Follow System," while `ColorScheme == nil` means no additional settings have been applied to the appearance.

With our `SchemeType` defined, the next step is to implement a selection page easily:

```swiftui
body {
  ...
  ForEach(SchemeType.allCases) { item in
      SelectionView(...)
  }
}
```



## 🕹️ Step Four: Global Management

By this juncture, everything is almost in place, and the only step remaining is to implement a global environment variable for unified management. We can define an `ObservableObject` as follows:

```swiftui
final class ColorSchemeState : ObservableObject {
    @AppStorage("systemColorSchemeValue") private var currentSchemeValue: Int = SchemeType.system.rawValue
    
    /// App's Selected Color Scheme
    var currentScheme: SchemeType {
        get {
            return SchemeType(rawValue: currentSchemeValue) ?? .system
        }
        set {
            currentSchemeValue = newValue.rawValue
        }
    }
}
```

Allow me to briefly clarify `ColorSchemeState`:

1. First, we used `@AppStorage` to declare a variable `currentSchemeValue` to record the selected appearance theme color, which is also synchronized in `UserDefaults`.
2. `currentScheme` is a public computed property provided to get the current appearance theme.
3. Since `ColorSchemeState` is an `ObservableObject`, the related UI will automatically update when the color scheme changes.

Next, upon app initialization, we only need to perform two tasks:

1. Set `colorSchemeState` as a global environment variable.
2. Use `preferredColorScheme` to set the default appearance color theme.

```swiftui
@main
struct XXXApp: App {
  // ... omitted for brevity
  @StateObject var colorSchemeState = ColorSchemeState()
  
  WindowGroup {
    MainView()
    // ... omitted for brevity
    	.preferredColorScheme(colorSchemeState.currentScheme.SystemColorScheme)
    	.environmentObject(colorSchemeState)
  }
}
```

If we wish to access color theme information on a specific page or even change the appearance selection, we can do so as follows:

```swiftui
@EnvironmentObject var colorSchemeState: ColorSchemeState
colorSchemeState.currentScheme = ...
```

And with that, our framework for global management is complete!
