#import "SquirrelPanel.h"

#import "SquirrelConfig.h"

static const int kOffsetHeight = 5;
static const int kDefaultFontSize = 24;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *const kDefaultCandidateFormat = @"%c. %@";

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSTextStorage *text;
@property(nonatomic, readonly) NSRange highlightedRange;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) CGFloat textFrameWidth;
@property(nonatomic, strong, readonly) NSColor *backgroundColor;
@property(nonatomic, strong, readonly) NSColor *highlightedStripColor;
@property(nonatomic, strong, readonly) NSColor *highlightedPreeditColor;
@property(nonatomic, strong, readonly) NSColor *preeditBackgroundColor;
@property(nonatomic, strong, readonly) NSColor *borderColor;

@property(nonatomic, assign) CGFloat cornerRadius;
@property(nonatomic, assign) CGFloat hilitedCornerRadius;
@property(nonatomic, assign) NSSize edgeInset;
@property(nonatomic, assign) CGFloat borderWidth;
@property(nonatomic, assign) CGFloat linespace;
@property(nonatomic, assign) CGFloat preeditLinespace;
@property(nonatomic, assign) BOOL linear;
@property(nonatomic, assign) BOOL vertical;
@property(nonatomic, assign) BOOL inlinePreedit;

@property(nonatomic, assign) CGFloat seperatorWidth;

- (BOOL)isFlipped;
- (void)setText:(NSAttributedString *)text;
- (void)drawViewWith:(NSRange)hilightedRange
        preeditRange:(NSRange)preeditRange
  highlightedPreeditRange:(NSRange)highlightedPreeditRange;
- (NSRect)contentRectForRange:(NSRange)range;
- (void)setBackgroundColor:(NSColor *)backgroundColor
     highlightedStripColor:(NSColor *)highlightedStripColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor;
- (void)setCornerRadius:(double)cornerRadius
hilitedCornerRadius:(double)hilitedCornerRadius
          edgeInset:(NSSize)edgeInset
        borderWidth:(double)borderWidth
          linespace:(double)linespace
   preeditLinespace:(double)preeditLinespace
         linear:(BOOL)linear
           vertical:(BOOL)vertical
      inlinePreedit:(BOOL)inlinePreedit;

@end

@implementation SquirrelView

// Need flipped coordinate system, as required by textStorage
- (BOOL)isFlipped {
  return YES;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;
  }
  // Use textStorage to store text and manage all text layout and draws
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSZeroSize];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  [layoutManager addTextContainer:textContainer];
  _text = [[NSTextStorage alloc] init];
  [_text addLayoutManager:layoutManager];
  layoutManager.backgroundLayoutEnabled = YES;
  return self;
}

// The textStorage layout will have a 5px empty edge on both sides
- (CGFloat)textFrameWidth {
  return [_text.layoutManagers[0] boundingRectForGlyphRange:NSMakeRange(0, 0) inTextContainer:_text.layoutManagers[0].textContainers[0]].origin.x;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  NSRange glyphRange = [_text.layoutManagers[0] glyphRangeForTextContainer:_text.layoutManagers[0].textContainers[0]];
  NSRect rect = [_text.layoutManagers[0] boundingRectForGlyphRange:glyphRange inTextContainer:_text.layoutManagers[0].textContainers[0]];
  CGFloat frameWidth = self.textFrameWidth;
  rect.origin.x -= frameWidth;
  rect.size.width += frameWidth * 2;
  return rect;
}

// Get the rectangle containing the range of text, will first convert to glyph range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  NSRange glyphRange = [_text.layoutManagers[0] glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  NSRect rect = [_text.layoutManagers[0] boundingRectForGlyphRange:glyphRange inTextContainer:_text.layoutManagers[0].textContainers[0]];
  return rect;
}

- (void)setText:(NSAttributedString *)text {
  [_text setAttributedString:[text copy]];
}

// Will triger - (void)drawRect:(NSRect)dirtyRect
- (void)drawViewWith:(NSRange)hilightedRange
         preeditRange:(NSRange)preeditRange
         highlightedPreeditRange:(NSRange)highlightedPreeditRange {
  _highlightedRange = hilightedRange;
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedPreeditRange;
  self.needsDisplay = YES;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
     highlightedStripColor:(NSColor *)highlightedStripColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor {
  _backgroundColor = backgroundColor;
  _highlightedStripColor = highlightedStripColor;
  _highlightedPreeditColor = highlightedPreeditColor;
  _preeditBackgroundColor = preeditBackgroundColor;
  _borderColor = borderColor;
}

- (void)setCornerRadius:(double)cornerRadius
    hilitedCornerRadius:(double)hilitedCornerRadius
              edgeInset:(NSSize)edgeInset
            borderWidth:(double)borderWidth
              linespace:(double)linespace
       preeditLinespace:(double)preeditLinespace
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit {
  _cornerRadius = cornerRadius;
  _hilitedCornerRadius = hilitedCornerRadius;
  _edgeInset = edgeInset;
  _borderWidth = borderWidth;
  _linespace = linespace;
  _preeditLinespace = preeditLinespace;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit;
}

// If an edge is close to border, will use border instead. To fix rounding errors
void checkBorders(NSRect *rect, NSRect boundary) {
  const CGFloat ROUND_UP = 1.0;
  double diff;
  if (NSMinX(*rect) - ROUND_UP < NSMinX(boundary)) {
    diff = NSMinX(*rect) - NSMinX(boundary);
    rect->origin.x -= diff;
    rect->size.width += diff;
  }
  if (NSMaxX(*rect) + ROUND_UP > NSMaxX(boundary)) {
    diff = NSMaxX(boundary) - NSMaxX(*rect);
    rect->size.width += diff;
  }
  if (NSMinY(*rect) - ROUND_UP < NSMinY(boundary)) {
    diff = NSMinY(*rect) - NSMinY(boundary);
    rect->origin.y -= diff;
    rect->size.height += diff;
  }
  if (NSMaxY(*rect) + ROUND_UP > NSMaxY(boundary)) {
    diff = NSMaxY(boundary) - NSMaxY(*rect);
    rect->size.height += diff;
  }
}

void makeRoomForConer(NSRect *rect, NSRect boundary, CGFloat corner) {
  const CGFloat ROUND_UP = 1.0;
  if (NSMinX(*rect) - ROUND_UP < NSMinX(boundary)) {
    rect->size.width -= corner;
    rect->origin.x += corner;
  }
  if (NSMaxX(*rect) + ROUND_UP > NSMaxX(boundary)) {
    rect->size.width -= corner;
  }
  if (NSMinY(*rect) - ROUND_UP < NSMinY(boundary)) {
    rect->size.height -= corner;
    rect->origin.y += corner;
  }
  if (NSMaxY(*rect) + ROUND_UP > NSMaxY(boundary)) {
    rect->size.height -= corner;
  }
}

// A tweaked sign function, to winddown corner radius when the size is small
double sign(double number) {
  if (number >= 2) {
    return 1;
  } else if (number <= -2) {
    return -1;
  }else {
    return number / 2;
  }
}

// Bezier cubic curve, which has continuous roundness
NSBezierPath *drawSmoothLines(NSArray<NSValue *> *vertex, CGFloat alpha, CGFloat beta) {
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint previousPoint = [vertex[vertex.count-1] pointValue];
  NSPoint point = [vertex[0] pointValue];
  NSPoint nextPoint;
  NSPoint control1;
  NSPoint control2;
  NSPoint target = previousPoint;
  NSPoint diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y);
  if (ABS(diff.x) >= ABS(diff.y)) {
    target.x += sign(diff.x/beta)*beta;
  } else {
    target.y += sign(diff.y/beta)*beta;
  }
  [path moveToPoint:target];
  for (NSUInteger i = 0; i < vertex.count; i += 1) {
    previousPoint = [vertex[(vertex.count+i-1)%vertex.count] pointValue];
    point = [vertex[i] pointValue];
    nextPoint = [vertex[(i+1)%vertex.count] pointValue];
    target = point;
    control1 = point;
    diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y);
    if (ABS(diff.x) >= ABS(diff.y)) {
      target.x -= sign(diff.x/beta)*beta;
      control1.x -= sign(diff.x/beta)*alpha;
    } else {
      target.y -= sign(diff.y/beta)*beta;
      control1.y -= sign(diff.y/beta)*alpha;
    }
    [path lineToPoint:target];
    target = point;
    control2 = point;
    diff = NSMakePoint(nextPoint.x - point.x, nextPoint.y - point.y);
    if (ABS(diff.x) > ABS(diff.y)) {
      control2.x += sign(diff.x/beta)*alpha;
      target.x += sign(diff.x/beta)*beta;
    } else {
      control2.y += sign(diff.y/beta)*alpha;
      target.y += sign(diff.y/beta)*beta;
    }
    [path curveToPoint:target controlPoint1:control1 controlPoint2:control2];
  }
  [path closePath];
  return path;
}

NSArray<NSValue *> *rectVertex(NSRect rect) {
  return @[
    @(rect.origin),
    @(NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)),
    @(NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)),
    @(NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y))
  ];
}

BOOL nearEmptyRect(NSRect rect) {
  return rect.size.height * rect.size.width < 1;
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
// bodyRect is complete lines in the middle
- (void)multilineRectForRange:(NSRange)charRange leadingRect:(NSRect *)leadingRect bodyRect:(NSRect *)bodyRect trailingRect:(NSRect *)trailingRect {
  NSLayoutManager *layoutManager = _text.layoutManagers[0];
  NSTextContainer *textContainer = layoutManager.textContainers[0];
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
  NSRect boundingRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
  NSRange fullRangeInBoundingRect = [layoutManager glyphRangeForBoundingRect:boundingRect inTextContainer:textContainer];
  *leadingRect = NSZeroRect;
  *bodyRect = boundingRect;
  *trailingRect = NSZeroRect;
  if (boundingRect.origin.x <= self.textFrameWidth +1 && fullRangeInBoundingRect.location < glyphRange.location) {
    *leadingRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(fullRangeInBoundingRect.location, glyphRange.location-fullRangeInBoundingRect.location) inTextContainer:textContainer];
    if (!nearEmptyRect(*leadingRect)) {
      bodyRect->size.height -= leadingRect->size.height;
      bodyRect->origin.y += leadingRect->size.height;
    }
    double rightEdge = NSMaxX(*leadingRect);
    leadingRect->origin.x = rightEdge;
    leadingRect->size.width = bodyRect->origin.x + bodyRect->size.width - rightEdge;
  }
  if (fullRangeInBoundingRect.location+fullRangeInBoundingRect.length > glyphRange.location+glyphRange.length) {
    *trailingRect = [layoutManager boundingRectForGlyphRange:
                    NSMakeRange(glyphRange.location+glyphRange.length, fullRangeInBoundingRect.location+fullRangeInBoundingRect.length-glyphRange.location-glyphRange.length)
                                                      inTextContainer:textContainer];
    if (!nearEmptyRect(*trailingRect)) {
      bodyRect->size.height -= trailingRect->size.height;
    }
    double leftEdge = NSMinX(*trailingRect);
    trailingRect->origin.x = bodyRect->origin.x;
    trailingRect->size.width = leftEdge - bodyRect->origin.x;
  } else if (fullRangeInBoundingRect.location+fullRangeInBoundingRect.length == glyphRange.location+glyphRange.length) {
    *trailingRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location+glyphRange.length-1 effectiveRange:NULL];
    if (NSMaxX(*trailingRect) >= NSMaxX(boundingRect) - 1) {
      *trailingRect = NSZeroRect;
    } else if (!nearEmptyRect(*trailingRect)) {
      bodyRect->size.height -= trailingRect->size.height;
    }
  }
  NSRect lastLineRect = nearEmptyRect(*trailingRect) ? *bodyRect : *trailingRect;
  lastLineRect.size.width = textContainer.containerSize.width - lastLineRect.origin.x;
  NSRange lastLineRange = [layoutManager glyphRangeForBoundingRect:lastLineRect inTextContainer:textContainer];
  NSGlyphProperty glyphProperty = [layoutManager propertyForGlyphAtIndex:lastLineRange.location+lastLineRange.length-1];
  while (lastLineRange.length>0 && (glyphProperty == NSGlyphPropertyElastic || glyphProperty == NSGlyphPropertyControlCharacter)) {
    lastLineRange.length -= 1;
    glyphProperty = [layoutManager propertyForGlyphAtIndex:lastLineRange.location+lastLineRange.length-1];
  }
  if (lastLineRange.location+lastLineRange.length == glyphRange.location+glyphRange.length) {
    if (!nearEmptyRect(*trailingRect)) {
      *trailingRect = lastLineRect;
    } else {
      *bodyRect = lastLineRect;
    }
  }
  leadingRect->origin.x += _edgeInset.width;
  leadingRect->origin.y += _edgeInset.height;
  bodyRect->origin.x += _edgeInset.width;
  bodyRect->origin.y += _edgeInset.height;
  trailingRect->origin.x += _edgeInset.width;
  trailingRect->origin.y += _edgeInset.height;
}

// Based on the 3 boxes from multilineRectForRange, calculate the vertex of the polygon containing the text in range
NSArray<NSValue *> * multilineRectVertex(NSRect leadingRect, NSRect bodyRect, NSRect trailingRect) {
  if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && nearEmptyRect(trailingRect)) {
    return rectVertex(leadingRect);
  } else if (nearEmptyRect(bodyRect) && nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect)) {
    return rectVertex(trailingRect);
  } else if (nearEmptyRect(leadingRect) && nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    return rectVertex(bodyRect);
  } else if (nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], leadingVertex[1], leadingVertex[0], leadingVertex[3], bodyVertex[2], bodyVertex[1]];
  } else if (nearEmptyRect(leadingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], bodyVertex[3], bodyVertex[2], trailingVertex[3], trailingVertex[2], trailingVertex[1]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && nearEmptyRect(bodyRect) && NSMaxX(leadingRect)>NSMinX(trailingRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[trailingVertex[0], leadingVertex[1], leadingVertex[0], leadingVertex[3], leadingVertex[2], trailingVertex[3], trailingVertex[2], trailingVertex[1]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[bodyVertex[0], leadingVertex[1], leadingVertex[0], leadingVertex[3], bodyVertex[2], trailingVertex[3], trailingVertex[2], trailingVertex[1]];
  } else {
    return @[];
  }
}

// If the point is outside the innerBox, will extend to reach the outerBox
void expand(NSMutableArray<NSValue *> *vertex, NSRect innerBorder, NSRect outerBorder) {
  for (NSUInteger i = 0; i < vertex.count; i += 1){
    NSPoint point = [vertex[i] pointValue];
    if (point.x < innerBorder.origin.x) {
      point.x = outerBorder.origin.x;
    } else if (point.x > innerBorder.origin.x+innerBorder.size.width) {
      point.x = outerBorder.origin.x+outerBorder.size.width;
    }
    if (point.y < innerBorder.origin.y) {
      point.y = outerBorder.origin.y;
    } else if (point.y > innerBorder.origin.y+innerBorder.size.height) {
      point.y = outerBorder.origin.y+outerBorder.size.height;
    }
    [vertex replaceObjectAtIndex:i withObject:@(point)];
  }
}

// Add gap between horizontal candidates
- (void)addGapBetweenHorizontalCandidates:(NSRect *)rect {
  if (_highlightedRange.location+_highlightedRange.length == _text.length) {
    if (!nearEmptyRect(*rect)) {
      rect->size.width += _seperatorWidth / 2;
      rect->origin.x -= _seperatorWidth / 2;
    }
  } else if (_highlightedRange.location - ((_preeditRange.location == NSNotFound ? 0 : _preeditRange.location)+_preeditRange.length) <= 1) {
    if (!nearEmptyRect(*rect)) {
      rect->size.width += _seperatorWidth / 2;
    }
  } else {
    if (!nearEmptyRect(*rect)) {
      rect->size.width += _seperatorWidth;
      rect->origin.x -= _seperatorWidth / 2;
    }
  }
}

// All draws happen here
- (void)drawRect:(NSRect)dirtyRect {
  double textFrameWidth = self.textFrameWidth;
  NSBezierPath *backgroundPath;
  NSBezierPath *borderPath;
  NSBezierPath *highlightedPath;
  NSBezierPath *highlightedPath2;
  NSBezierPath *highlightedPreeditPath;
  NSBezierPath *highlightedPreeditPath2;
  NSBezierPath *preeditPath;
  NSColor *borderColor = _borderColor;
  CGFloat halfLinespace = _linespace / 2;

  NSRect textField = dirtyRect;
  textField.origin.y += _edgeInset.height;
  textField.origin.x += _edgeInset.width;
  
  // Draw preedit Rect
  NSRect backgroundRect = dirtyRect;
  
  // Draw preedit Rect
  NSRect preeditRect = NSZeroRect;
  if (_preeditRange.length > 0) {
    preeditRect = [self contentRectForRange:_preeditRange];
    preeditRect.size.width = textField.size.width;
    preeditRect.size.height += _preeditLinespace;
    preeditRect.origin = NSMakePoint(textField.origin.x - _edgeInset.width, textField.origin.y - _edgeInset.height);
    preeditRect.size.height += _edgeInset.height;
    if (_highlightedRange.location - (_preeditRange.location+_preeditRange.length) <= 1) {
      if (_preeditRange.length > 0 && !_linear) {
        preeditRect.size.height -= _hilitedCornerRadius / 2;
      }
    }
    if (_highlightedRange.length == 0) {
      preeditRect.size.height += _edgeInset.height - _preeditLinespace;
    }
    checkBorders(&preeditRect, backgroundRect);
    if (_preeditBackgroundColor != nil) {
      preeditPath = drawSmoothLines(rectVertex(preeditRect), 0, 0);
    }
  }
  
  // Draw highlighted Rect
  if (_highlightedRange.length > 0 && _highlightedStripColor != nil) {
    if (_linear){
      NSRect leadingRect;
      NSRect bodyRect;
      NSRect trailingRect;
      [self multilineRectForRange:_highlightedRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
      
      [self addGapBetweenHorizontalCandidates:&leadingRect];
      [self addGapBetweenHorizontalCandidates:&bodyRect];
      [self addGapBetweenHorizontalCandidates:&trailingRect];
      
      NSRect innerBox = backgroundRect;
      innerBox.size.width -= (_edgeInset.width + 1 + textFrameWidth) * 2;
      innerBox.origin.x += _edgeInset.width + 1 + textFrameWidth;
      if (_preeditRange.length == 0) {
        innerBox.origin.y += _edgeInset.height + 1;
        innerBox.size.height -= (_edgeInset.height + 1) * 2;
      } else {
        innerBox.origin.y += preeditRect.size.height + halfLinespace + 1;
        innerBox.size.height -= _edgeInset.height + preeditRect.size.height + halfLinespace + 2;
      }
      NSRect outerBox = backgroundRect;
      outerBox.size.height -= _hilitedCornerRadius + preeditRect.size.height;
      outerBox.size.width -= _hilitedCornerRadius;
      outerBox.origin.x += _hilitedCornerRadius / 2;
      outerBox.origin.y += _hilitedCornerRadius / 2 + preeditRect.size.height;
      
      NSMutableArray<NSValue *> *highlightedPoints;
      NSMutableArray<NSValue *> *highlightedPoints2;
      // Handles the special case where containing boxes are separated
      if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPoints = [rectVertex(leadingRect) mutableCopy];
        highlightedPoints2 = [rectVertex(trailingRect) mutableCopy];
      } else {
        highlightedPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
      }
      // Expand the boxes to reach proper border
      expand(highlightedPoints, innerBox, outerBox);
      expand(highlightedPoints2, innerBox, outerBox);
      highlightedPath = drawSmoothLines(highlightedPoints, 0.3*_hilitedCornerRadius, 1.4*_hilitedCornerRadius);
      if (highlightedPoints2.count > 0) {
        highlightedPath2 = drawSmoothLines(highlightedPoints2, 0.3*_hilitedCornerRadius, 1.4*_hilitedCornerRadius);
      }
    } else {
      NSRect highlightedRect = [self contentRectForRange:_highlightedRange];
      highlightedRect.size.width = textField.size.width;
      highlightedRect.size.height += _linespace;
      highlightedRect.origin = NSMakePoint(textField.origin.x - _edgeInset.width, highlightedRect.origin.y + _edgeInset.height - halfLinespace);
      if (_highlightedRange.location+_highlightedRange.length == _text.length) {
        highlightedRect.size.height += _edgeInset.height - halfLinespace;
      }
      if (_highlightedRange.location - ((_preeditRange.location == NSNotFound ? 0 : _preeditRange.location)+_preeditRange.length) <= 1) {
        if (_preeditRange.length == 0) {
          highlightedRect.size.height += _edgeInset.height - halfLinespace;
          highlightedRect.origin.y -= _edgeInset.height - halfLinespace;
        } else {
          highlightedRect.size.height += _hilitedCornerRadius / 2;
          highlightedRect.origin.y -= _hilitedCornerRadius / 2;
        }
      }
      if (_hilitedCornerRadius == 0) {
        // fill in small gaps between highlighted rect and the bounding rect.
        checkBorders(&highlightedRect, backgroundRect);
      } else {
        // leave a small gap between highlighted rect and the bounding rect
        NSRect candidateRect = backgroundRect;
        candidateRect.size.height -= preeditRect.size.height;
        candidateRect.origin.y += preeditRect.size.height;
        makeRoomForConer(&highlightedRect, candidateRect, _hilitedCornerRadius / 2);

      }
      highlightedPath = drawSmoothLines(rectVertex(highlightedRect), _hilitedCornerRadius*0.3, _hilitedCornerRadius*1.4);
    }
  }
  
  // Draw highlighted part of preedit text
  if (_highlightedPreeditRange.length > 0 && _highlightedPreeditColor != nil) {
    NSRect leadingRect;
    NSRect bodyRect;
    NSRect trailingRect;
    [self multilineRectForRange:_highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];

    NSRect innerBox = preeditRect;
    innerBox.size.width -= (_edgeInset.width + 1 + textFrameWidth) * 2;
    innerBox.origin.x += _edgeInset.width + 1 + textFrameWidth;
    innerBox.origin.y += _edgeInset.height + 1;
    if (_highlightedRange.length == 0) {
      innerBox.size.height -= (_edgeInset.height + 1) * 2;
    } else {
      innerBox.size.height -= _edgeInset.height+_preeditLinespace + 2;
    }
    NSRect outerBox = preeditRect;
    outerBox.size.height -= _hilitedCornerRadius;
    outerBox.size.width -= _hilitedCornerRadius;
    outerBox.origin.x += _hilitedCornerRadius / 2;
    outerBox.origin.y += _hilitedCornerRadius / 2;
    
    NSMutableArray<NSValue *> *highlightedPreeditPoints;
    NSMutableArray<NSValue *> *highlightedPreeditPoints2;
    // Handles the special case where containing boxes are separated
    if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
      highlightedPreeditPoints = [rectVertex(leadingRect) mutableCopy];
      highlightedPreeditPoints2 = [rectVertex(trailingRect) mutableCopy];
    } else {
      highlightedPreeditPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
    }
    // Expand the boxes to reach proper border
    expand(highlightedPreeditPoints, innerBox, outerBox);
    expand(highlightedPreeditPoints2, innerBox, outerBox);
    highlightedPreeditPath = drawSmoothLines(highlightedPreeditPoints, 0.3*_hilitedCornerRadius, 1.4*_hilitedCornerRadius);
    if (highlightedPreeditPoints2.count > 0) {
      highlightedPreeditPath2 = drawSmoothLines(highlightedPreeditPoints2, 0.3*_hilitedCornerRadius, 1.4*_hilitedCornerRadius);
    }
  }

  [NSBezierPath setDefaultLineWidth:0];
  backgroundPath = drawSmoothLines(rectVertex(backgroundRect), _cornerRadius*0.3, _cornerRadius*1.4);
  // Nothing should extend beyond backgroundPath
  borderPath = [backgroundPath copy];
  [borderPath addClip];
  borderPath.lineWidth = _borderWidth;

// This block of code enables independent transparencies in highlighted colour and background colour.
// Disabled because of the flaw: edges or rounded corners of the heighlighted area are rendered with undesirable shadows.
#if 0
  // Calculate intersections.
  if (![highlightedPath isEmpty]) {
    [backgroundPath appendBezierPath:[highlightedPath copy]];
    if (![highlightedPath2 isEmpty]) {
      [backgroundPath appendBezierPath:[highlightedPath2 copy]];
    }
  }
  
  if (![preeditPath isEmpty]) {
    [backgroundPath appendBezierPath:[preeditPath copy]];
  }
  
  if (![highlightedPreeditPath isEmpty]) {
    if (preeditPath != nil) {
      [preeditPath appendBezierPath:[highlightedPreeditPath copy]];
    } else {
      [backgroundPath appendBezierPath:[highlightedPreeditPath copy]];
    }
    if (![highlightedPreeditPath2 isEmpty]) {
      if (preeditPath != nil) {
        [preeditPath appendBezierPath:[highlightedPreeditPath2 copy]];
      } else {
        [backgroundPath appendBezierPath:[highlightedPreeditPath2 copy]];
      }
    }
  }
  [backgroundPath setWindingRule:NSEvenOddWindingRule];
  [preeditPath setWindingRule:NSEvenOddWindingRule];
#endif

  [_backgroundColor setFill];
  [backgroundPath fill];
  if (_preeditBackgroundColor && ![preeditPath isEmpty]) {
    [_preeditBackgroundColor setFill];
    [preeditPath fill];
  }
  if (_highlightedStripColor && ![highlightedPath isEmpty]) {
    [_highlightedStripColor setFill];
    [highlightedPath fill];
    if (![highlightedPath2 isEmpty]) {
      [highlightedPath2 fill];
    }
  }
  if (_highlightedPreeditColor && ![highlightedPreeditPath isEmpty]) {
    [_highlightedPreeditColor setFill];
    [highlightedPreeditPath fill];
    if (![highlightedPreeditPath2 isEmpty]) {
      [highlightedPreeditPath2 fill];
    }
  }

  if (borderColor) {
    [borderColor setStroke];
    [borderPath stroke];
  }
  NSRange glyphRange = [_text.layoutManagers[0] glyphRangeForTextContainer:_text.layoutManagers[0].textContainers[0]];
  [_text.layoutManagers[0] drawGlyphsForGlyphRange:glyphRange atPoint:textField.origin];
}

@end

@implementation SquirrelPanel {
  NSWindow *_window;
  SquirrelView *_view;

  NSString *_candidateFormat;
  NSMutableDictionary *_attrs;
  NSMutableDictionary *_highlightedAttrs;
  NSMutableDictionary *_labelAttrs;
  NSMutableDictionary *_labelHighlightedAttrs;
  NSMutableDictionary *_commentAttrs;
  NSMutableDictionary *_commentHighlightedAttrs;
  NSMutableDictionary *_preeditAttrs;
  NSMutableDictionary *_preeditHighlightedAttrs;
  NSParagraphStyle *_paragraphStyle;
  NSParagraphStyle *_preeditParagraphStyle;
  CGFloat _alphaValue;
  
  NSRange _preeditRange;
  NSRect _screenRect;
  CGFloat _maxHeight;

  NSString *_statusMessage;
  NSTimer *_statusTimer;
}

CGFloat minimumHeight(NSDictionary *attribute) {
  const NSAttributedString *spaceChar = [[NSAttributedString alloc] initWithString:@" " attributes:attribute];
  const CGFloat minimumHeight = [spaceChar boundingRectWithSize:NSZeroSize options:NULL].size.height;
  return minimumHeight;
}

// Use this method to convert charcters to upright position
// Based on the width of the chacter, relative font size matters
void convertToVerticalGlyph(NSMutableAttributedString *originalText, NSRange stringRange) {
  NSDictionary *attribute = [originalText attributesAtIndex:stringRange.location effectiveRange:NULL];
  double baseOffset = [attribute[NSBaselineOffsetAttributeName] doubleValue];
  // Use the width of the character to determin if they should be upright in vertical writing mode.
  // Adjust font base line for better alignment.
  const NSAttributedString *cjkChar = [[NSAttributedString alloc] initWithString:@"字" attributes:attribute];
  const NSRect cjkRect = [cjkChar boundingRectWithSize:NSZeroSize options:NULL];
  const NSAttributedString *hangulChar = [[NSAttributedString alloc] initWithString:@"글" attributes:attribute];
  const NSSize hangulSize = [hangulChar boundingRectWithSize:NSZeroSize options:NULL].size;
  stringRange = [originalText.string rangeOfComposedCharacterSequencesForRange:stringRange];
  NSUInteger i = stringRange.location;
  while (i < stringRange.location+stringRange.length) {
    NSRange range = [originalText.string rangeOfComposedCharacterSequenceAtIndex:i];
    i = range.location + range.length;
    NSRect charRect = [[originalText attributedSubstringFromRange:range] boundingRectWithSize:NSZeroSize options:NULL];
    // Also adjust the baseline so upright and lying charcters are properly aligned
    if ((charRect.size.width >= cjkRect.size.width) || (charRect.size.width >= hangulSize.width)) {
      [originalText addAttribute:NSVerticalGlyphFormAttributeName value:@(1) range:range];
      NSRect uprightCharRect = [[originalText attributedSubstringFromRange:range] boundingRectWithSize:NSZeroSize options:NULL];
      CGFloat widthDiff = charRect.size.width-cjkChar.size.width;
      CGFloat offset = (cjkRect.size.height - uprightCharRect.size.height)/2 + (cjkRect.origin.y-uprightCharRect.origin.y) - (widthDiff>0 ? widthDiff/1.2 : widthDiff/2) +baseOffset;
      [originalText addAttribute:NSBaselineOffsetAttributeName value:@(offset) range:range];
    } else {
      [originalText addAttribute:NSBaselineOffsetAttributeName value:@(baseOffset) range:range];
    }
  }
}

- (void)initializeUIStyle {
  _candidateFormat = kDefaultCandidateFormat;
  {
    _attrs = [[NSMutableDictionary alloc] init];
    _attrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
    _attrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

    _highlightedAttrs = [[NSMutableDictionary alloc] init];
    _highlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedControlTextColor];
    _highlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

    _labelAttrs = [_attrs mutableCopy];
    _labelHighlightedAttrs = [_highlightedAttrs mutableCopy];

    _commentAttrs = [[NSMutableDictionary alloc] init];
    _commentAttrs[NSForegroundColorAttributeName] = [NSColor disabledControlTextColor];
    _commentAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

    _commentHighlightedAttrs = [_commentAttrs mutableCopy];

    _preeditAttrs = [[NSMutableDictionary alloc] init];
    _preeditAttrs[NSForegroundColorAttributeName] = [NSColor disabledControlTextColor];
    _preeditAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

    _preeditHighlightedAttrs = [[NSMutableDictionary alloc] init];
    _preeditHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
    _preeditHighlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

    _preeditParagraphStyle = [NSParagraphStyle defaultParagraphStyle];
    _preeditParagraphStyle = [NSParagraphStyle defaultParagraphStyle];
  }
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _window = [[NSWindow alloc] initWithContentRect:_position
                                          styleMask:NSWindowStyleMaskBorderless
                                            backing:NSBackingStoreBuffered
                                              defer:YES];
    _window.alphaValue = 1.0;
    // _window.level = NSScreenSaverWindowLevel + 1;
    // ^ May fix visibility issue in fullscreen games.
    _window.level = CGShieldingWindowLevel();
    _window.hasShadow = YES;
    _window.opaque = NO;
    _window.backgroundColor = [NSColor clearColor];
    _view = [[SquirrelView alloc] initWithFrame:_window.contentView.frame];
    _window.contentView = _view;
    [self initializeUIStyle];
    _maxHeight = 0;
  }
  return self;
}

- (void)getCurrentScreen {
  // get current screen
  _screenRect = [NSScreen mainScreen].frame;
  NSArray *screens = [NSScreen screens];
  
  NSUInteger i;
  for (i = 0; i < screens.count; ++i) {
    NSRect rect = [screens[i] frame];
    if (NSPointInRect(_position.origin, rect)) {
      _screenRect = rect;
      break;
    }
  }
}

// Get the window size, the windows will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  [self getCurrentScreen];

  //Break line if the text is too long, based on screen size.
  NSSize edgeInset = _view.edgeInset;
  CGFloat textWidth = _view.text.size.width + _view.textFrameWidth * 2;
  if (_vertical && (textWidth > NSHeight(_screenRect) / 3 - edgeInset.height * 2)) {
    textWidth = NSHeight(_screenRect) / 3 - edgeInset.height * 2;
  } else if (!_vertical && (textWidth > NSWidth(_screenRect) / 2 - edgeInset.height * 2)) {
    textWidth = NSWidth(_screenRect) / 2 - edgeInset.height * 2;
  }
  _view.text.layoutManagers[0].textContainers[0].containerSize = NSMakeSize(textWidth, 0);
  
  NSRect windowRect;
  // in vertical mode, the width and height are interchanged
  NSRect contentRect = _view.contentRect;
  if ((_vertical && NSMidY(_position) / NSHeight(_screenRect) < 0.5) ||
      (!_vertical && NSMinX(_position)+MAX(contentRect.size.width, _maxHeight)+edgeInset.width*2 > NSMaxX(_screenRect))) {
    if (contentRect.size.width >= _maxHeight) {
      _maxHeight = contentRect.size.width;
    } else {
      contentRect.size.width = _maxHeight;
      _view.text.layoutManagers[0].textContainers[0].containerSize = NSMakeSize(_maxHeight, 0);
    }
  }
  
  if (_vertical) {
    windowRect.size = NSMakeSize(contentRect.size.height + edgeInset.height * 2,
                                 contentRect.size.width + edgeInset.width * 2);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMidY(_position) / NSHeight(_screenRect) >= 0.5) {
      windowRect.origin.y = NSMinY(_position) - kOffsetHeight - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + kOffsetHeight;
    }
    // Make the first candidate fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - windowRect.size.width - kOffsetHeight;
    if (_preeditRange.length > 0) {
      NSSize preeditSize = [_view contentRectForRange:_preeditRange].size;
      windowRect.origin.x += preeditSize.height + edgeInset.width;
    }
  } else {
    windowRect.size = NSMakeSize(contentRect.size.width + edgeInset.width * 2,
                                 contentRect.size.height + edgeInset.height * 2);
    windowRect.origin = NSMakePoint(NSMinX(_position),
                                    NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
  }

  if (NSMaxX(windowRect) > NSMaxX(_screenRect)) {
    windowRect.origin.x = NSMaxX(_screenRect) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(_screenRect)) {
    windowRect.origin.x = NSMinX(_screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(_screenRect)) {
    if (_vertical) {
      windowRect.origin.y = NSMinY(_screenRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + kOffsetHeight;
    }
  }
  if (NSMaxY(windowRect) > NSMaxY(_screenRect)) {
    windowRect.origin.y = NSMaxY(_screenRect) - NSHeight(windowRect);
  }
  if (NSMinY(windowRect) < NSMinY(_screenRect)) {
    windowRect.origin.y = NSMinY(_screenRect);
  }
  // rotate the view, the core in vertical mode!
  if (_vertical) {
    _view.boundsRotation = 90.0;
    [_view setBoundsOrigin:NSMakePoint(0, windowRect.size.width)];
  } else {
    _view.boundsRotation = 0;
    [_view setBoundsOrigin:NSMakePoint(0, 0)];
  }
  _window.alphaValue = _alphaValue;
  [_window setFrame:windowRect display:YES];
  [_window invalidateShadow];
  [_window orderFront:nil];
  // voila !
}

- (void)hide {
  if (_statusTimer) {
    [_statusTimer invalidate];
    _statusTimer = nil;
  }
  [_window orderOut:nil];
  _maxHeight = 0;
}

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray *)candidates
           comments:(NSArray *)comments
             labels:(NSArray *)labels
        highlighted:(NSUInteger)index {
  NSUInteger numCandidates = candidates.count;
  if (numCandidates || (preedit && preedit.length)) {
    _statusMessage = nil;
    if (_statusTimer) {
      [_statusTimer invalidate];
      _statusTimer = nil;
    }
  } else {
    if (_statusMessage) {
      [self showStatus:_statusMessage];
      _statusMessage = nil;
    } else if (!_statusTimer) {
      [self hide];
    }
    return;
  }

  NSRange labelRange, labelRange2, pureCandidateRange;
  NSString *labelFormat, *labelFormat2, *pureCandidateFormat;
  {
    // in our candiate format, everything other than '%@' is
    // considered as a part of the label

    labelRange = [_candidateFormat rangeOfString:@"%c"];
    if (labelRange.location == NSNotFound) {
      labelRange2 = labelRange;
      labelFormat2 = labelFormat = nil;

      pureCandidateRange = NSMakeRange(0, _candidateFormat.length);
      pureCandidateFormat = _candidateFormat;
    } else {
      pureCandidateRange = [_candidateFormat rangeOfString:@"%@"];
      if (pureCandidateRange.location == NSNotFound) {
        // this should never happen, but just ensure that Squirrel
        // would not crash when such edge case occurs...

        labelFormat = _candidateFormat;

        labelRange2 = pureCandidateRange;
        labelFormat2 = nil;

        pureCandidateFormat = @"";
      } else {
        if (NSMaxRange(pureCandidateRange) >= _candidateFormat.length) {
          // '%@' is at the end, so label2 does not exist
          labelRange2 = NSMakeRange(NSNotFound, 0);
          labelFormat2 = nil;

          // fix label1, everything other than '%@' is label1
          labelRange.location = 0;
          labelRange.length = pureCandidateRange.location;
        } else {
          labelRange = NSMakeRange(0, pureCandidateRange.location);
          labelRange2 = NSMakeRange(NSMaxRange(pureCandidateRange),
                                    _candidateFormat.length -
                                        NSMaxRange(pureCandidateRange));

          labelFormat2 = [_candidateFormat substringWithRange:labelRange2];
        }

        pureCandidateFormat = @"%@";
        labelFormat = [_candidateFormat substringWithRange:labelRange];
      }
    }
  }
  
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
  NSUInteger candidateStartPos = 0;
  _preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  // preedit
  if (preedit) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
    if (selRange.location > 0) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                 initWithString:[preedit substringToIndex:selRange.location].precomposedStringWithCanonicalMapping
                        attributes:_preeditAttrs]];
    }
    if (selRange.length > 0) {
      NSUInteger highlightedPreeditStart = line.length;
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[preedit substringWithRange:selRange].precomposedStringWithCanonicalMapping
                        attributes:_preeditHighlightedAttrs]];
      highlightedPreeditRange = NSMakeRange(highlightedPreeditStart, line.length - highlightedPreeditStart);
    }
    if (selRange.location + selRange.length < preedit.length) {
      [line
          appendAttributedString:
              [[NSAttributedString alloc]
                  initWithString:[preedit substringFromIndex:selRange.location +
                                                             selRange.length].precomposedStringWithCanonicalMapping
                      attributes:_preeditAttrs]];
    }
    [text appendAttributedString:line];

    NSMutableParagraphStyle *paragraphStylePreedit = [_preeditParagraphStyle mutableCopy];
    if (_vertical) {
      convertToVerticalGlyph(text, NSMakeRange(0, line.length));
      paragraphStylePreedit.minimumLineHeight = minimumHeight(_preeditAttrs);
    }
    [text addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStylePreedit
                 range:NSMakeRange(0, text.length)];
    
    _preeditRange = NSMakeRange(0, text.length);
    if (numCandidates) {
      [text appendAttributedString:[[NSAttributedString alloc]
                    initWithString:@"\n"
                        attributes:_preeditAttrs]];
    }
    candidateStartPos = text.length;
  }
  
  // For vertical mode, before appending candidates, copy the front workflow
  // of candidates to get the max width of candidates, so that the spacing
  // between candidate and comment can be calculated later.
  NSSize maxCandidateSize = NSZeroSize;
  if (!_linear) {
    NSUInteger i;
    for (i = 0; i < candidates.count; ++i) {
      NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    NSString *labelString;
    if (labels.count > 1 && i < labels.count) {
      labelFormat = [labelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      labelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
    } else if (labels.count == 1 && i < [labels[0] length]) {
      // custom: A. B. C...
      char labelCharacter = [labels[0] characterAtIndex:i];
      labelString = [NSString stringWithFormat:labelFormat, labelCharacter];
    } else {
      // default: 1. 2. 3...
      labelFormat = [labelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
      labelString = [NSString stringWithFormat:labelFormat, i+1];
    }

    NSDictionary *attrs = (i == index) ? _highlightedAttrs : _attrs;
    NSDictionary *labelAttrs = (i == index) ? _labelHighlightedAttrs : _labelAttrs;

    CGFloat labelWidth = 0.0;
    if (labelRange.location != NSNotFound) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:labelString
                        attributes:labelAttrs]];
      // get the label size for indent
      if (_vertical) {
        convertToVerticalGlyph(line, NSMakeRange(0, line.length));
      }
      if (!_linear) {
        labelWidth = [line boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin].size.width;
      }
    }

    NSUInteger candidateStart = line.length;
    NSString *candidate = candidates[i];
    [line appendAttributedString:[[NSAttributedString alloc]
                                     initWithString:candidate.precomposedStringWithCanonicalMapping
                                         attributes:attrs]];
    // Use left-to-right marks to prevent right-to-left text from changing the
    // layout of non-candidate text.
    [line addAttribute:NSWritingDirectionAttributeName value:@[@0] range:NSMakeRange(candidateStart, line.length-candidateStart)];

    if (labelRange2.location != NSNotFound) {
      NSString *labelString2;
      if (labels.count > 1 && i < labels.count) {
        labelFormat2 = [labelFormat2 stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
        labelString2 = [NSString stringWithFormat:labelFormat2, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        char labelCharacter = [labels[0] characterAtIndex:i];
        labelString2 = [NSString stringWithFormat:labelFormat2, labelCharacter];
      } else {
        // default: 1. 2. 3...
        labelFormat2 = [labelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
        labelString2 = [NSString stringWithFormat:labelFormat, i+1];
      }
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:labelString2
                        attributes:labelAttrs]];
    }

      if (i < comments.count && [comments[i] length] != 0) {
        if (maxCandidateSize.width < line.size.width) {
          maxCandidateSize.width = line.size.width;
        }
      }
    }
  }

  NSRange highlightedRange = NSMakeRange(NSNotFound, 0);
  // candidates
  NSUInteger i;
  for (i = 0; i < candidates.count; ++i) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    NSString *labelString;
    if (labels.count > 1 && i < labels.count) {
      labelFormat = [labelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      labelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
    } else if (labels.count == 1 && i < [labels[0] length]) {
      // custom: A. B. C...
      char labelCharacter = [labels[0] characterAtIndex:i];
      labelString = [NSString stringWithFormat:labelFormat, labelCharacter];
    } else {
      // default: 1. 2. 3...
      labelFormat = [labelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
      labelString = [NSString stringWithFormat:labelFormat, i+1];
    }

    NSDictionary *attrs = (i == index) ? _highlightedAttrs : _attrs;
    NSDictionary *labelAttrs = (i == index) ? _labelHighlightedAttrs : _labelAttrs;
    NSDictionary *commentAttrs = (i == index) ? _commentHighlightedAttrs : _commentAttrs;

    CGFloat labelWidth = 0.0;
    if (labelRange.location != NSNotFound) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:labelString
                        attributes:labelAttrs]];
      // get the label size for indent
      if (_vertical) {
        convertToVerticalGlyph(line, NSMakeRange(0, line.length));
      }
      if (!_linear) {
        labelWidth = [line boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin].size.width;
      }
    }

    NSUInteger candidateStart = line.length;
    NSString *candidate = candidates[i];
    [line appendAttributedString:[[NSAttributedString alloc]
                                     initWithString:candidate.precomposedStringWithCanonicalMapping
                                         attributes:attrs]];
    // Use left-to-right marks to prevent right-to-left text from changing the
    // layout of non-candidate text.
    [line addAttribute:NSWritingDirectionAttributeName value:@[@0] range:NSMakeRange(candidateStart, line.length-candidateStart)];

    if (labelRange2.location != NSNotFound) {
      NSString *labelString2;
      if (labels.count > 1 && i < labels.count) {
        labelFormat2 = [labelFormat2 stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
        labelString2 = [NSString stringWithFormat:labelFormat2, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        char labelCharacter = [labels[0] characterAtIndex:i];
        labelString2 = [NSString stringWithFormat:labelFormat2, labelCharacter];
      } else {
        // default: 1. 2. 3...
        labelFormat2 = [labelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
        labelString2 = [NSString stringWithFormat:labelFormat, i+1];
      }
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:labelString2
                        attributes:labelAttrs]];
    }

    if (i < comments.count && [comments[i] length] != 0) {
      if (_linear) {
        [line appendAttributedString:[[NSAttributedString alloc]
                                        initWithString:@" "
                                            attributes:_attrs]];
      } else {
        while (line.size.width <= maxCandidateSize.width) {
          [line appendAttributedString:[[NSAttributedString alloc]
                                        initWithString:@"\t"
                                            attributes:_attrs]];
        }
      }

      NSString *comment = comments[i];
      [line appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:comment.precomposedStringWithCanonicalMapping
                                           attributes:commentAttrs]];
    }
    
    
    NSAttributedString *separator = [[NSMutableAttributedString alloc]
                                        initWithString:(_linear ? @"  " : @"\n")
                                            attributes:attrs];
    _view.seperatorWidth = [separator boundingRectWithSize:NSZeroSize options:NULL].size.width;
    if (i > 0) {
      [text appendAttributedString:separator];
    }

    NSMutableParagraphStyle *paragraphStyleCandidate = [_paragraphStyle mutableCopy];
    if (_vertical) {
      convertToVerticalGlyph(line, NSMakeRange(candidateStart, line.length-candidateStart));
      paragraphStyleCandidate.minimumLineHeight = minimumHeight(attrs);
    }
    paragraphStyleCandidate.headIndent = labelWidth;
    [line addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, line.length)];
    
    if (i == index) {
      highlightedRange = NSMakeRange(text.length, line.length);
    }
    [text appendAttributedString:line];
  }
  // text done!
  [_view setText:text];
  [_view drawViewWith:highlightedRange preeditRange:_preeditRange highlightedPreeditRange:highlightedPreeditRange];
  [self show];
}

- (void)updateStatus:(NSString *)message {
  _statusMessage = message;
}

- (void)showStatus:(NSString *)message {
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:message
                                                                           attributes:_commentAttrs];
  if (_vertical) {
    convertToVerticalGlyph(text, NSMakeRange(0, text.length));
  }
  [_view setText:text];
  NSRange emptyRange = NSMakeRange(NSNotFound, 0);
  [_view drawViewWith:emptyRange preeditRange:emptyRange highlightedPreeditRange:emptyRange];
  [self show];

  if (_statusTimer) {
    [_statusTimer invalidate];
  }
  _statusTimer = [NSTimer scheduledTimerWithTimeInterval:kShowStatusDuration
                                                  target:self
                                                selector:@selector(hideStatus:)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)hideStatus:(NSTimer *)timer {
  [self hide];
}

static inline NSColor *blendColors(NSColor *foregroundColor,
                                   NSColor *backgroundColor) {
  if (!backgroundColor) {
    // return foregroundColor;
    backgroundColor = [NSColor lightGrayColor];
  }

  struct {
    CGFloat r, g, b, a;
  } f, b;

  [[foregroundColor colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]]
      getRed:&f.r
       green:&f.g
        blue:&f.b
       alpha:&f.a];
  //NSLog(@"fg: %f %f %f %f", f.r, f.g, f.b, f.a);

  [[backgroundColor colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]]
      getRed:&b.r
       green:&b.g
        blue:&b.b
       alpha:&b.a];
  //NSLog(@"bg: %f %f %f %f", b.r, b.g, b.b, b.a);

#define blend_value(f, b) (((f)*2.0 + (b)) / 3.0)
  return [NSColor colorWithDeviceRed:blend_value(f.r, b.r)
                               green:blend_value(f.g, b.g)
                                blue:blend_value(f.b, b.b)
                               alpha:f.a];
#undef blend_value
}

static NSFontDescriptor *getFontDescriptor(NSString *fullname) {
  if (fullname == nil) {
    return nil;
  }

  NSArray *fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray *validFontDescriptors = [NSMutableArray arrayWithCapacity:fontNames.count];
  for (__strong NSString *fontName in fontNames) {
    fontName = [fontName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([NSFont fontWithName:fontName size:0.0] != nil) {
      // If the font name is not valid, NSFontDescriptor will still create something for us.
      // However, when we draw the actual text, Squirrel will crash if there is any font descriptor
      // with invalid font name.
      [validFontDescriptors addObject:[NSFontDescriptor fontDescriptorWithName:fontName
                                                                          size:0.0]];
    }
  }
  if (validFontDescriptors.count == 0) {
    return nil;
  } else if (validFontDescriptors.count == 1) {
    return validFontDescriptors[0];
  }

  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  NSArray *fallbackDescriptors = [validFontDescriptors
      subarrayWithRange:NSMakeRange(1, validFontDescriptors.count - 1)];
  NSDictionary *attributes = @{NSFontCascadeListAttribute : fallbackDescriptors};
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

static void updateCandidateListLayout(BOOL *isLinearCandidateList, SquirrelConfig *config, NSString *prefix) {
  NSString* candidateListLayout = [config getString:[prefix stringByAppendingString:@"/candidate_list_layout"]];
  if ([candidateListLayout isEqualToString:@"stacked"]) {
    *isLinearCandidateList = false;
  } else if ([candidateListLayout isEqualToString:@"linear"]) {
    *isLinearCandidateList = true;
  } else {
    // Deprecated. Not to be confused with text_orientation: horizontal
    NSNumber *horizontal = [config getOptionalBool:[prefix stringByAppendingString:@"/horizontal"]];
    if (horizontal) {
      *isLinearCandidateList = horizontal.boolValue;
    }
  }
}

static void updateTextOrientation(BOOL *isVerticalText, SquirrelConfig *config, NSString *prefix) {
  NSString* textOrientation = [config getString:[prefix stringByAppendingString:@"/text_orientation"]];
  if ([textOrientation isEqualToString:@"horizontal"]) {
    *isVerticalText = false;
  } else if ([textOrientation isEqualToString:@"vertical"]) {
    *isVerticalText = true;
  } else {
    NSNumber *vertical = [config getOptionalBool:[prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVerticalText = vertical.boolValue;
    }
  }
}

-(void)updateConfig:(SquirrelConfig *)config {
  updateCandidateListLayout(&_linear, config, @"style");
  updateTextOrientation(&_vertical, config, @"style");
  _inlinePreedit = [config getBool:@"style/inline_preedit"];
  NSString *candidateFormat = [config getString:@"style/candidate_format"];
  _candidateFormat = candidateFormat ? candidateFormat : kDefaultCandidateFormat;

  NSString *fontName = [config getString:@"style/font_face"];
  NSInteger fontSize = [config getInt:@"style/font_point"];
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  NSInteger labelFontSize = [config getInt:@"style/label_font_point"];
  CGFloat alpha = fmin(fmax([config getDouble:@"style/alpha"], 0.0), 1.0);
  CGFloat cornerRadius = [config getDouble:@"style/corner_radius"];
  CGFloat hilitedCornerRadius = [config getDouble:@"style/hilited_corner_radius"];
  CGFloat borderHeight = [config getDouble:@"style/border_height"];
  CGFloat borderWidth = [config getDouble:@"style/border_width"];
  CGFloat lineSpacing = [config getDouble:@"style/line_spacing"];
  CGFloat spacing = [config getDouble:@"style/spacing"];
  CGFloat baseOffset = [config getDouble:@"style/base_offset"];

  NSColor *backgroundColor;
  NSColor *borderColor;
  NSColor *preeditBackgroundColor;
  NSColor *candidateLabelColor;
  NSColor *highlightedCandidateLabelColor;
  NSColor *textColor;
  NSColor *highlightedTextColor;
  NSColor *highlightedBackColor;
  NSColor *candidateTextColor;
  NSColor *highlightedCandidateTextColor;
  NSColor *highlightedCandidateBackColor;
  NSColor *commentTextColor;
  NSColor *highlightedCommentTextColor;
  
  NSString *colorScheme = [config getString:@"style/color_scheme"];
  if (colorScheme) {
    NSString *prefix = [@"preset_color_schemes/" stringByAppendingString:colorScheme];
    backgroundColor = [config getColor:[prefix stringByAppendingString:@"/back_color"]];
    borderColor = [config getColor:[prefix stringByAppendingString:@"/border_color"]];
    preeditBackgroundColor = [config getColor:[prefix stringByAppendingString:@"/preedit_back_color"]];
    textColor = [config getColor:[prefix stringByAppendingString:@"/text_color"]];
    highlightedTextColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_text_color"]];
    if (highlightedTextColor == nil) {
      highlightedTextColor = textColor;
    }
    highlightedBackColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_back_color"]];
    candidateTextColor =
        [config getColor:[prefix stringByAppendingString:@"/candidate_text_color"]];
    if (candidateTextColor == nil) {
      // in non-inline mode, 'text_color' is for rendering preedit text.
      // if not otherwise specified, candidate text is also rendered in this color.
      candidateTextColor = textColor;
    }
    highlightedCandidateTextColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_text_color"]];
    if (highlightedCandidateTextColor == nil) {
      highlightedCandidateTextColor = highlightedTextColor;
    }
    highlightedCandidateBackColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_back_color"]];
    if (highlightedCandidateBackColor == nil) {
      highlightedCandidateBackColor = highlightedBackColor;
    }
    commentTextColor =
        [config getColor:[prefix stringByAppendingString:@"/comment_text_color"]];
    highlightedCommentTextColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_comment_text_color"]];

    // the following per-color-scheme configurations, if exist, will
    // override configurations with the same name under the global 'style' section

    updateCandidateListLayout(&_linear, config, prefix);
    updateTextOrientation(&_vertical, config, prefix);

    NSNumber *inlinePreeditOverridden =
        [config getOptionalBool:[prefix stringByAppendingString:@"/inline_preedit"]];
    if (inlinePreeditOverridden) {
      _inlinePreedit = inlinePreeditOverridden.boolValue;
    }
    NSString *candidateFormatOverridden =
        [config getString:[prefix stringByAppendingString:@"/candidate_format"]];
    if (candidateFormatOverridden) {
      _candidateFormat = candidateFormatOverridden;
    }

    NSString *fontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/font_face"]];
    if (fontNameOverridden) {
      fontName = fontNameOverridden;
    }
    NSNumber *fontSizeOverridden =
        [config getOptionalInt:[prefix stringByAppendingString:@"/font_point"]];
    if (fontSizeOverridden) {
      fontSize = fontSizeOverridden.integerValue;
    }
    NSString *labelFontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/label_font_face"]];
    if (labelFontNameOverridden) {
      labelFontName = labelFontNameOverridden;
    }
    NSNumber *labelFontSizeOverridden =
        [config getOptionalInt:[prefix stringByAppendingString:@"/label_font_point"]];
    if (labelFontSizeOverridden) {
      labelFontSize = labelFontSizeOverridden.integerValue;
    }
    NSColor *candidateLabelColorOverridden =
        [config getColor:[prefix stringByAppendingString:@"/label_color"]];
    if (candidateLabelColorOverridden) {
      candidateLabelColor = candidateLabelColorOverridden;
    }
    NSColor *highlightedCandidateLabelColorOverridden =
        [config getColor:[prefix stringByAppendingString:@"/label_hilited_color"]];
    if (!highlightedCandidateLabelColorOverridden) {
      // for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color'
      // are both valid
      highlightedCandidateLabelColorOverridden =
          [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]];
    }
    if (highlightedCandidateLabelColorOverridden) {
      highlightedCandidateLabelColor = highlightedCandidateLabelColorOverridden;
    }
    NSNumber *alphaOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/alpha"]];
    if (alphaOverridden) {
      alpha = fmin(fmax(alphaOverridden.doubleValue, 0.0), 1.0);
    }
    NSNumber *cornerRadiusOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/corner_radius"]];
    if (cornerRadiusOverridden) {
      cornerRadius = cornerRadiusOverridden.doubleValue;
    }
    NSNumber *hilitedCornerRadiusOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]];
    if (hilitedCornerRadiusOverridden) {
      hilitedCornerRadius = hilitedCornerRadiusOverridden.doubleValue;
    }
    NSNumber *borderHeightOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/border_height"]];
    if (borderHeightOverridden) {
      borderHeight = borderHeightOverridden.doubleValue;
    }
    NSNumber *borderWidthOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/border_width"]];
    if (borderWidthOverridden) {
      borderWidth = borderWidthOverridden.doubleValue;
    }
    NSNumber *lineSpacingOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/line_spacing"]];
    if (lineSpacingOverridden) {
      lineSpacing = lineSpacingOverridden.doubleValue;
    }
    NSNumber *spacingOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/spacing"]];
    if (spacingOverridden) {
      spacing = spacingOverridden.doubleValue;
    }
    NSNumber *baseOffsetOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/base_offset"]];
    if (baseOffsetOverridden) {
      baseOffset = baseOffsetOverridden.doubleValue;
    }
  }

  if (fontSize == 0) { // default size
    fontSize = kDefaultFontSize;
  }
  if (labelFontSize == 0) {
    labelFontSize = fontSize;
  }
  NSFontDescriptor *fontDescriptor = nil;
  NSFont *font = nil;
  if (fontName != nil) {
    fontDescriptor = getFontDescriptor(fontName);
    if (fontDescriptor != nil) {
      font = [NSFont fontWithDescriptor:fontDescriptor size:fontSize];
    }
  }
  if (font == nil) {
    // use default font
    font = [NSFont userFontOfSize:fontSize];
  }
  NSFontDescriptor *labelFontDescriptor = nil;
  NSFont *labelFont = nil;
  if (labelFontName != nil) {
    labelFontDescriptor = getFontDescriptor(labelFontName);
    if (labelFontDescriptor == nil) {
      labelFontDescriptor = fontDescriptor;
    }
    if (labelFontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize];
    }
  }
  if (labelFont == nil) {
    if (fontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:fontDescriptor size:labelFontSize];
    } else {
      labelFont = [NSFont fontWithName:font.fontName size:labelFontSize];
    }
  }
  
  NSMutableParagraphStyle *paragraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  paragraphStyle.paragraphSpacing = lineSpacing / 2;
  paragraphStyle.paragraphSpacingBefore = lineSpacing / 2;

  NSMutableParagraphStyle *preeditParagraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  preeditParagraphStyle.paragraphSpacing = spacing;

  {
    _attrs[NSFontAttributeName] = font;
    _highlightedAttrs[NSFontAttributeName] = font;
    _labelAttrs[NSFontAttributeName] = labelFont;
    _labelHighlightedAttrs[NSFontAttributeName] = labelFont;
    _commentAttrs[NSFontAttributeName] = font;
    _commentHighlightedAttrs[NSFontAttributeName] = font;
    _preeditAttrs[NSFontAttributeName] = font;
    _preeditHighlightedAttrs[NSFontAttributeName] = font;
    _attrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _highlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _labelAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _labelHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _commentAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _commentHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _preeditAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
    _paragraphStyle = paragraphStyle;
    _preeditParagraphStyle = preeditParagraphStyle;
  }
  backgroundColor = backgroundColor ? backgroundColor : [NSColor windowBackgroundColor];
  candidateTextColor = candidateTextColor ? candidateTextColor : [NSColor controlTextColor];
  candidateLabelColor = candidateLabelColor ? candidateLabelColor : blendColors(candidateTextColor, backgroundColor);
  highlightedCandidateTextColor = highlightedCandidateTextColor ? highlightedCandidateTextColor : [NSColor selectedControlTextColor];
  highlightedCandidateBackColor = highlightedCandidateBackColor ? highlightedCandidateBackColor : [NSColor selectedTextBackgroundColor];
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? highlightedCandidateLabelColor
    : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? commentTextColor : [NSColor disabledControlTextColor];
  highlightedCommentTextColor = highlightedCommentTextColor ? highlightedCommentTextColor : commentTextColor;
  textColor = textColor ? textColor : [NSColor disabledControlTextColor];
  highlightedTextColor = highlightedTextColor ? highlightedTextColor : [NSColor controlTextColor];
  {
    _attrs[NSForegroundColorAttributeName] = candidateTextColor;
    _labelAttrs[NSForegroundColorAttributeName] = candidateLabelColor;
    _highlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateTextColor;
    _labelHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateLabelColor;
    _commentAttrs[NSForegroundColorAttributeName] = commentTextColor;
    _commentHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCommentTextColor;
    _preeditAttrs[NSForegroundColorAttributeName] = textColor;
    _preeditHighlightedAttrs[NSForegroundColorAttributeName] = highlightedTextColor;
  }
  [_view setBackgroundColor:backgroundColor
      highlightedStripColor:highlightedCandidateBackColor
    highlightedPreeditColor:highlightedBackColor
     preeditBackgroundColor:preeditBackgroundColor
                borderColor:borderColor];
  
  NSSize edgeInset;
  if (_vertical) {
    edgeInset = NSMakeSize(MAX(borderHeight, cornerRadius), MAX(borderWidth, cornerRadius));
  } else {
    edgeInset = NSMakeSize(MAX(borderWidth, cornerRadius), MAX(borderHeight, cornerRadius));
  }
  [_view setCornerRadius:cornerRadius
     hilitedCornerRadius:hilitedCornerRadius
               edgeInset:edgeInset
             borderWidth:MIN(borderHeight, borderWidth)
               linespace:lineSpacing
        preeditLinespace:spacing
              linear:_linear
                vertical:_vertical
           inlinePreedit:_inlinePreedit];

  _alphaValue = (alpha == 0) ? 1.0 : alpha;
}
@end
