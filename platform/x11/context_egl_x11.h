#ifndef CONTEXT_EGL_X11_H
#define CONTEXT_EGL_X11_H

#if defined(X11_ENABLED) && defined(OPENGL_ENABLED) && defined(X11_EGL_ENABLED)

#include "core/os/os.h"

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <X11/Xlib.h>

class ContextEGL_X11 {
public:
	enum ContextType {
		GLES_2_0_COMPATIBLE,
		GLES_3_0_COMPATIBLE
	};

private:
	OS::VideoMode default_video_mode;
	::Display *x11_display;
	::Window &x11_window;
	EGLDisplay egl_display;
	EGLContext egl_context;
	EGLSurface egl_surface;
	EGLConfig egl_config;
	bool use_vsync;
	ContextType context_type;

public:
	void release_current();
	void make_current();
	void swap_buffers();
	int get_window_width();
	int get_window_height();
	EGLDisplay get_egl_display() const;
	EGLContext get_egl_context() const;

	Error initialize();

	void set_use_vsync(bool p_use);
	bool is_using_vsync() const;

	ContextEGL_X11(::Display *p_x11_display, ::Window &p_x11_window, const OS::VideoMode &p_default_video_mode, ContextType p_context_type);
	~ContextEGL_X11();
};

#endif

#endif
