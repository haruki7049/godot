/*************************************************************************/
/*  context_egl_x11.cpp                                                  */
/*************************************************************************/
/*                       This file is part of:                           */
/*                           GODOT ENGINE                                */
/*                      https://godotengine.org                          */
/*************************************************************************/
/* Copyright (c) 2007-2021 Juan Linietsky, Ariel Manzur.                 */
/* Copyright (c) 2014-2021 Godot Engine contributors (cf. AUTHORS.md).   */
/*                                                                       */
/* Permission is hereby granted, free of charge, to any person obtaining */
/* a copy of this software and associated documentation files (the       */
/* "Software"), to deal in the Software without restriction, including   */
/* without limitation the rights to use, copy, modify, merge, publish,   */
/* distribute, sublicense, and/or sell copies of the Software, and to    */
/* permit persons to whom the Software is furnished to do so, subject to */
/* the following conditions:                                             */
/*                                                                       */
/* The above copyright notice and this permission notice shall be        */
/* included in all copies or substantial portions of the Software.       */
/*                                                                       */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF    */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.*/
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE     */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                */
/*************************************************************************/

#include "context_egl_x11.h"

#if defined(X11_ENABLED) && defined(OPENGL_ENABLED) && defined(X11_EGL_ENABLED)

#include <string.h>

#include <X11/extensions/Xrender.h>

static bool has_egl_extension(const char *exts, const char *name) {
	if (!exts || !name || !*name) {
		return false;
	}
	const char *start = exts;
	while ((start = strstr(start, name)) != nullptr) {
		const char *end = start + strlen(name);
		if ((start == exts || start[-1] == ' ') && (*end == ' ' || *end == '\0')) {
			return true;
		}
		start = end;
	}
	return false;
}

static void set_class_hint(Display *p_display, Window p_window) {
	XClassHint *classHint;

	/* set the name and class hints for the window manager to use */
	classHint = XAllocClassHint();
	if (classHint) {
		classHint->res_name = (char *)"Godot_Engine";
		classHint->res_class = (char *)"Godot";
	}
	XSetClassHint(p_display, p_window, classHint);
	XFree(classHint);
}

void ContextEGL_X11::release_current() {
	if (egl_display != EGL_NO_DISPLAY) {
		eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
	}
}

void ContextEGL_X11::make_current() {
	if (egl_display != EGL_NO_DISPLAY && egl_surface != EGL_NO_SURFACE && egl_context != EGL_NO_CONTEXT) {
		eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context);
	}
}

void ContextEGL_X11::swap_buffers() {
	if (egl_display != EGL_NO_DISPLAY && egl_surface != EGL_NO_SURFACE) {
		eglSwapBuffers(egl_display, egl_surface);
	}
}

Error ContextEGL_X11::initialize() {
	EGLDisplay display = EGL_NO_DISPLAY;

	PFNEGLGETPLATFORMDISPLAYEXTPROC eglGetPlatformDisplayEXT =
			(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
	if (eglGetPlatformDisplayEXT) {
#ifdef EGL_PLATFORM_X11_EXT
		display = eglGetPlatformDisplayEXT(EGL_PLATFORM_X11_EXT, (void *)x11_display, nullptr);
#endif
	}
	if (display == EGL_NO_DISPLAY) {
		display = eglGetDisplay((EGLNativeDisplayType)x11_display);
	}
	ERR_FAIL_COND_V(display == EGL_NO_DISPLAY, ERR_UNCONFIGURED);

	EGLint major = 0;
	EGLint minor = 0;
	ERR_FAIL_COND_V(eglInitialize(display, &major, &minor) == EGL_FALSE, ERR_UNCONFIGURED);

	ERR_FAIL_COND_V(!eglBindAPI(EGL_OPENGL_API), ERR_UNCONFIGURED);

	static EGLint config_attribs[] = {
		EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
		EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
		EGL_RED_SIZE, 1,
		EGL_GREEN_SIZE, 1,
		EGL_BLUE_SIZE, 1,
		EGL_DEPTH_SIZE, 24,
		EGL_NONE
	};

	static EGLint config_attribs_layered[] = {
		EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
		EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
		EGL_RED_SIZE, 8,
		EGL_GREEN_SIZE, 8,
		EGL_BLUE_SIZE, 8,
		EGL_ALPHA_SIZE, 8,
		EGL_DEPTH_SIZE, 24,
		EGL_NONE
	};

	EGLint num_configs = 0;
	EGLConfig config = nullptr;
	if (OS::get_singleton()->is_layered_allowed()) {
		ERR_FAIL_COND_V(eglChooseConfig(display, config_attribs_layered, &config, 1, &num_configs) == EGL_FALSE || num_configs < 1, ERR_UNCONFIGURED);
	} else {
		ERR_FAIL_COND_V(eglChooseConfig(display, config_attribs, &config, 1, &num_configs) == EGL_FALSE || num_configs < 1, ERR_UNCONFIGURED);
	}

	EGLint visual_id = 0;
	ERR_FAIL_COND_V(eglGetConfigAttrib(display, config, EGL_NATIVE_VISUAL_ID, &visual_id) == EGL_FALSE || visual_id == 0, ERR_UNCONFIGURED);

	XVisualInfo vinfo_template;
	vinfo_template.visualid = (VisualID)visual_id;
	int num_vis = 0;
	XVisualInfo *vi = XGetVisualInfo(x11_display, VisualIDMask, &vinfo_template, &num_vis);
	ERR_FAIL_COND_V(!vi, ERR_UNCONFIGURED);

	XSetWindowAttributes swa;
	swa.event_mask = StructureNotifyMask;
	swa.border_pixel = 0;
	unsigned long valuemask = CWBorderPixel | CWColormap | CWEventMask;

	if (OS::get_singleton()->is_layered_allowed()) {
		XRenderPictFormat *pict_format = XRenderFindVisualFormat(x11_display, vi->visual);
		if (!pict_format || pict_format->direct.alphaMask == 0) {
			XFree(vi);
			ERR_FAIL_V(ERR_UNCONFIGURED);
		}

		swa.background_pixmap = None;
		swa.background_pixel = 0;
		swa.border_pixmap = None;
		valuemask |= CWBackPixel;
	}

	swa.colormap = XCreateColormap(x11_display, RootWindow(x11_display, vi->screen), vi->visual, AllocNone);
	x11_window = XCreateWindow(x11_display, RootWindow(x11_display, vi->screen), 0, 0, OS::get_singleton()->get_video_mode().width, OS::get_singleton()->get_video_mode().height, 0, vi->depth, InputOutput, vi->visual, valuemask, &swa);
	XStoreName(x11_display, x11_window, "Godot Engine");

	if (!x11_window) {
		XFree(vi);
		ERR_FAIL_V(ERR_UNCONFIGURED);
	}
	set_class_hint(x11_display, x11_window);

	if (!OS::get_singleton()->is_no_window_mode_enabled()) {
		XMapWindow(x11_display, x11_window);
	}

	XSync(x11_display, False);

	EGLSurface surface = eglCreateWindowSurface(display, config, (EGLNativeWindowType)x11_window, nullptr);
	if (surface == EGL_NO_SURFACE) {
		XFree(vi);
		ERR_FAIL_V(ERR_UNCONFIGURED);
	}

	const char *exts = eglQueryString(display, EGL_EXTENSIONS);
	const bool has_khr_create_context = has_egl_extension(exts, "EGL_KHR_create_context");

	EGLContext context = EGL_NO_CONTEXT;
	if (context_type == GLES_3_0_COMPATIBLE) {
		if (!has_khr_create_context) {
			XFree(vi);
			ERR_FAIL_V(ERR_UNCONFIGURED);
		}

		EGLint ctx_attribs[] = {
			EGL_CONTEXT_MAJOR_VERSION_KHR, 3,
			EGL_CONTEXT_MINOR_VERSION_KHR, 3,
			EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
			EGL_NONE
		};
		context = eglCreateContext(display, config, EGL_NO_CONTEXT, ctx_attribs);
		if (context == EGL_NO_CONTEXT) {
			XFree(vi);
			ERR_FAIL_V(ERR_UNCONFIGURED);
		}
	} else {
		if (has_khr_create_context) {
			EGLint ctx_attribs[] = {
				EGL_CONTEXT_MAJOR_VERSION_KHR, 2,
				EGL_CONTEXT_MINOR_VERSION_KHR, 1,
				EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT_KHR,
				EGL_NONE
			};
			context = eglCreateContext(display, config, EGL_NO_CONTEXT, ctx_attribs);
		}

		if (context == EGL_NO_CONTEXT) {
			context = eglCreateContext(display, config, EGL_NO_CONTEXT, nullptr);
		}
		if (context == EGL_NO_CONTEXT) {
			XFree(vi);
			ERR_FAIL_V(ERR_UNCONFIGURED);
		}
	}

	if (eglMakeCurrent(display, surface, surface, context) == EGL_FALSE) {
		XFree(vi);
		ERR_FAIL_V(ERR_UNCONFIGURED);
	}

	XFree(vi);

	egl_display = display;
	egl_context = context;
	egl_surface = surface;
	egl_config = config;

	return OK;
}

int ContextEGL_X11::get_window_width() {
	XWindowAttributes xwa;
	XGetWindowAttributes(x11_display, x11_window, &xwa);

	return xwa.width;
}

int ContextEGL_X11::get_window_height() {
	XWindowAttributes xwa;
	XGetWindowAttributes(x11_display, x11_window, &xwa);

	return xwa.height;
}

EGLDisplay ContextEGL_X11::get_egl_display() const {
	return egl_display;
}

EGLContext ContextEGL_X11::get_egl_context() const {
	return egl_context;
}

void ContextEGL_X11::set_use_vsync(bool p_use) {
	if (egl_display != EGL_NO_DISPLAY) {
		if (eglSwapInterval(egl_display, p_use ? 1 : 0) == EGL_TRUE) {
			use_vsync = p_use;
		}
	}
}

bool ContextEGL_X11::is_using_vsync() const {
	return use_vsync;
}

ContextEGL_X11::ContextEGL_X11(::Display *p_x11_display, ::Window &p_x11_window, const OS::VideoMode &p_default_video_mode, ContextType p_context_type) :
		x11_window(p_x11_window) {
	default_video_mode = p_default_video_mode;
	x11_display = p_x11_display;
	context_type = p_context_type;
	egl_display = EGL_NO_DISPLAY;
	egl_context = EGL_NO_CONTEXT;
	egl_surface = EGL_NO_SURFACE;
	egl_config = nullptr;
	use_vsync = false;
}

ContextEGL_X11::~ContextEGL_X11() {
	if (egl_display != EGL_NO_DISPLAY) {
		eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
		if (egl_surface != EGL_NO_SURFACE) {
			eglDestroySurface(egl_display, egl_surface);
		}
		if (egl_context != EGL_NO_CONTEXT) {
			eglDestroyContext(egl_display, egl_context);
		}
		eglTerminate(egl_display);
	}
}

#endif
