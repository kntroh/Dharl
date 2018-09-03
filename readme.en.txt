
Dharl - The Pixel Art Editor
============================

What's this?
------------

The Dharl is a low feature pixel art editor. It is a free software.

The Dharl designed based on the design of the "キャラクタレイザー1999" that once existed on Japan.


Usage
-----

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


Build Process
-------------

For 32-bit systems:

    dub build

For 64-bit systems:

    dub build --arch=x86_64

Specify `--build=gui` to build without a console. When creating a release build, specify `--build=release`.
