Output docs/stampede-demo.gif
Set Width 1200
Set Height 700
Set FontSize 14
Set FontFamily "SF Mono"
Set Theme "GitHub Dark"
Set Padding 20
Set Framerate 12

Type "cd ~/stampede-app && swift build 2>&1 | tail -1"
Enter
Sleep 6s

Type "echo '✅ Build complete — launching Stampede App...'"
Enter
Sleep 1.5s

Type "open $(swift build --show-bin-path)/StampedeUI"
Enter
Sleep 2s

Type "echo '🖥️  macOS app launched! Now showing terminal dashboard:'"
Enter
Sleep 1.5s

Type "~/dev/terminal-stampede/ui/terminal/dashboard.sh --demo"
Enter
Sleep 6s
Sleep 2s
Sleep 2s

Type "q"
Sleep 1s
