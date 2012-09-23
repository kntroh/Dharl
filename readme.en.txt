
+++ Dharl - The Pixelation Editor +++

+ What's this? +

The Dharl is small feature pixelation editor. It is an example of DWT application.
The Dharl designed based on the design of the `�L�����N�^���C�U�[1999` that once existed on Japan.

+ Usage +

The window of the Dharl is divided into two areas roughly.

+--------+--------+
|        |        |
| Paint  | Image  |
|   Area |   List |
|        |        |
+--------+--------+

The Paint Area is equipped the drawable area and tools for your painting operation.
The Image List is viewer of some images. You can pop image from the Image List to the Paint Area, and you can push image of the Paint Area to the List.

Your work flow is as follows for example:

 1. Opens image or creates image. The image will be shown on the Image List.
 2. Pops image from the Image List with right click on the image in the Image List. Pixel data and palette will be displayed on the Paint Area.
 3. Edits the image with painting tools, on the Paint Area.
 4. Pushes edited image to the Image List with left click on the Image List.
 5. Saves the image with Ctrl+S.


+ Build Process +

Require dmd 2.059 and DWT2 (https://github.com/d-widget-toolkit/dwt) to build of the Dharl.

Build the Dharl with this command:
---
rdmd build
---

If want to build the release version:
---
rdmd build release
---