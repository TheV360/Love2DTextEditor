# ![Pretty Icon, Again](resources/icon.png) Love2D Text Editor

This is a text editor, built in Love2D from scratch.

# To-do

* ~~Nice indentation~~
* Saving and loading
* Scrollbar
* Basic syntax highlighting
* More particles
* Refactor some things
* Somehow make the question mark look less weird.
* Maybe expand this into a full fantasy console sorta thing?
	* API? (Love2D API but smaller)
	* Specs? (Most likely 360x240 full color)
	* Limits? (Probably not)
	* SmileBASIC-inspired?
	* Inputs? Mouse and keyboard? Mouse, keyboard, gamepad?

# [2024] ..But it never seems to actually open?

Oh! Sorry, it reads from `stdin` for its initial state. If you do `cat game.lua | love .` it'll appear with its source code like it did before. If you're on Windows, what are you doing?! (I think you can press Ctrl+D on both platforms to close the `stdin` and let Love2D start.)

# License

Just don't steal it and pass it off as your own thing, okay?

# Credits

* Me - All code, and resources.
* [Code In The Dark](https://github.com/codeinthedark)'s [Power Mode](http://codeinthedark.com/editor/) - Somehow inspiring me indirectly because [a bunch of people recreated the effects](https://github.com/codeinthedark/awesome-power-mode) and posted them onto Twitter, and then I somehow found one tweet and yeah.
