#InstaMath

This iOS app was my senior project at BYU-Idaho. It's an app that takes a picture of a simple (one-line) math equation and try's to read it and solve it. I decided to build this because the area of focus for my senior project was image processing. As for implementation, I was not allowed to use any third party libraries that helped with image processing, so I (kind of) created my mini-OCR engine. As you can see from the code I'm not using any machine learning techniques/ data-mining techniques to solve character recognition. I am only using my own algorithms for patter recognition. At the time, it seemed like the safest/best option to go this way. Looking back on it, it would've made much more sense to implement something like a neural network and have a database where I could store a big set of numbers to pull from to do analysis.

#Limitations
* This app works best on white paper with black text.
* It's important to only take picture of text and no other object while trying to process an equation
* As of right now, it's not handling some errors very gracefully, but I'll work on that soon.

https://developer.apple.com/documentation/vision/recognizing_text_in_images
