extern "C" {
    void ruby_sysinit(int *, char ***);
    void ruby_init(void);
    void ruby_init_loadpath(void);
    void ruby_script(const char *);
    void ruby_set_argv(int, char **);
    void rb_vm_init_compiler(void);
    void rb_vm_init_jit(void);
    void rb_vm_aot_feature_provide(const char *, void *);
    void *rb_vm_top_self(void);
    void rb_rb2oc_exc_handler(void);
    void rb_exit(int);
void MREP_95C2F47DF63D4457911EA6B07E65AEBD(void *, void *);
void MREP_6314672C6E874B7083E16AF4505D5954(void *, void *);
void MREP_CA9D1EDACD3A49D1A46804DA9D1EB0F1(void *, void *);
void MREP_122D83F2B5E5460BB2886605BDD50EC7(void *, void *);
void MREP_9E16E296BAD541D7832602FE0C313D0C(void *, void *);
}

extern "C"
void
RubyMotionInit(int argc, char **argv)
{
    static bool initialized = false;
    if (!initialized) {
	ruby_init();
	ruby_init_loadpath();
        if (argc > 0) {
	    const char *progname = argv[0];
	    ruby_script(progname);
	}
#if !__LP64__
	try {
#endif
	    void *self = rb_vm_top_self();
MREP_95C2F47DF63D4457911EA6B07E65AEBD(self, 0);
MREP_6314672C6E874B7083E16AF4505D5954(self, 0);
MREP_CA9D1EDACD3A49D1A46804DA9D1EB0F1(self, 0);
MREP_122D83F2B5E5460BB2886605BDD50EC7(self, 0);
MREP_9E16E296BAD541D7832602FE0C313D0C(self, 0);
#if !__LP64__
	}
	catch (...) {
	    rb_rb2oc_exc_handler();
	}
#endif
	initialized = true;
    }
}
