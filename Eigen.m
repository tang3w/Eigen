// Eigen.m
//
// Copyright (c) 2013 Tang Tianyong
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
// KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
// AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import "Eigen.h"
#import <objc/runtime.h>

struct Block_literal {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor {
        unsigned long int reserved;     // NULL
        unsigned long int size;         // sizeof(struct Block_literal_1)
        // optional helper functions
        void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
        void (*dispose_helper)(void *src);             // IFF (1<<25)
        // required ABI.2010.3.16
        const char *signature;                         // IFF (1<<30)
    } *descriptor;
    // imported variables
};

enum Block_flags {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};

const char *BlockSig(id block) {
    struct Block_literal *blk = (__bridge struct Block_literal *)block;
    enum Block_flags flag = blk->flags;
    
    if (flag & BLOCK_HAS_SIGNATURE) {
        void *signature = blk->descriptor;
        signature += sizeof(unsigned long int);
        signature += sizeof(unsigned long int);
        
        if (flag & BLOCK_HAS_COPY_DISPOSE) {
            signature += sizeof(void(*)(void *dst, void *src));
            signature += sizeof(void (*)(void *src));
        }
        
        return (*(const char **)signature);
    }
    
    return NULL;
}

@implementation Eigen {
    Class _klass;
}

+ (void)eigenInstance:(id)instance handler:(EigenInstanceHandler)handler {
    static unsigned long long suffix = 0;
    
    Class cls = [instance class];
    const char *name = [[NSString stringWithFormat:@"%s#%llu", class_getName(cls), ++suffix] UTF8String];
    
    Eigen *eigen = nil;
    Class eigenclass = Nil;
    
    if (objc_getClass(name) == nil) {
        eigenclass = objc_allocateClassPair(object_getClass(instance), name, 0);
        
        if (eigenclass != Nil) {
            const char *types = method_getTypeEncoding(class_getInstanceMethod(cls, @selector(class)));
            class_addMethod(eigenclass, @selector(class), imp_implementationWithBlock(^(id s){return cls;}), types);
            
            objc_registerClassPair(eigenclass);
            object_setClass(instance, eigenclass);
            
            eigen = [[Eigen alloc] initWithKlass:eigenclass];
        }
    }
    
    handler(instance, eigen);
}

- (id)initWithKlass:(id)klass {
    self = [super init];
    
    if (self) {
        _klass = klass;
    }
    
    return self;
}

- (id)klass {
    return _klass;
}

- (instancetype)addMethod:(SEL)selector byBlock:(id)block {
    const char *sig = BlockSig(block);
    if (sig != NULL) {
        class_addMethod(_klass, selector, imp_implementationWithBlock(block), sig);
    }
    
    return self;
}

- (id)superBlock:(SEL)selector {
    Class superclass = class_getSuperclass(_klass);
    
    if (superclass != Nil) {
        IMP imp = class_getMethodImplementation(superclass, selector);
        if (imp != NULL) {
            return imp_getBlock(imp);
        }
    }
    
    return nil;
}

- (IMP)superImplementation:(SEL)selector {
    Class superclass = class_getSuperclass(_klass);
    
    return class_getMethodImplementation(superclass, selector);
}

@end
