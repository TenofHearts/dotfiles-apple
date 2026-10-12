ObjC.import('AppKit');
ObjC.import('CoreGraphics');
$.NSApplication.sharedApplication;
var windows = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0)));
var screens = $.NSScreen.screens;
var primary = screens.objectAtIndex(0).frame;
var ceiling = primary.origin.y + primary.size.height;
var result = [];
for (var i = 0; i < screens.count; i++) {
    var screen = screens.objectAtIndex(i);
    var frame = screen.frame;
    var visible = screen.visibleFrame;
    var top = ceiling - frame.origin.y - frame.size.height;
    // Hidden menus sit just above the screen; visible menus sit at its top.
    var menus = windows.filter(function(w) {
        var b = w.kCGWindowBounds;
        return w.kCGWindowLayer === 24 && b &&
            w.kCGWindowOwnerName === 'Window Server' &&
            Math.abs(b.X - frame.origin.x) < 1 &&
            Math.abs(b.Width - frame.size.width) < 1 &&
            b.Height > 0 && b.Height < 100 &&
            Math.abs(b.Y - top) <= b.Height + 1;
    });
    result.push({
        screen: i + 1,
        notch: screen.safeAreaInsets.top > 0,
        inset: Math.max(0, frame.origin.y + frame.size.height -
            visible.origin.y - visible.size.height),
        height: menus.length ? Math.min.apply(null, menus.map(function(w) {
            return w.kCGWindowBounds.Height;
        })) : null
    });
}
JSON.stringify(result);
