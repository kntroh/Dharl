
/// This module includes functions for creating DWT widgets easily.
module dharl.ui.dwtfactory;

public import dwtutils.utils;

private import dharl.ui.cslider;

private import org.eclipse.swt.all;

/// Creates basic style CSlider.
CSlider basicCSlider(Composite parent, int style, int min, int max, int pageIncrement) {
	auto scale = new CSlider(parent, style);
	scale.p_minimum = min;
	scale.p_maximum = max;
	scale.p_pageIncrement = pageIncrement;
	return scale;
}
/// ditto
CSlider basicHCSlider(Composite parent, int min, int max, int increment) {
	return basicCSlider(parent, SWT.HORIZONTAL, min, max, increment);
}
/// ditto
CSlider basicVCSlider(Composite parent, int min, int max, int increment) {
	return basicCSlider(parent, SWT.VERTICAL, min, max, increment);
}
