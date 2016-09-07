/* Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "charmony.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* For rmdir */
#ifdef CHY_HAS_UNISTD_H
  #include <unistd.h>
#endif
#ifdef CHY_HAS_DIRECT_H
  #include <direct.h>
#endif

#define CFC_USE_TEST_MACROS
#include "CFCBase.h"
#include "CFCClass.h"
#include "CFCFile.h"
#include "CFCHierarchy.h"
#include "CFCParcel.h"
#include "CFCTest.h"
#include "CFCUtil.h"

#define AUTOGEN          "autogen"
#define AUTOGEN_INCLUDE  AUTOGEN CHY_DIR_SEP "include"
#define AUTOGEN_SOURCE   AUTOGEN CHY_DIR_SEP "source"

static void
S_run_tests(CFCTest *test);

static void
S_run_basic_tests(CFCTest *test);

static void
S_run_include_tests(CFCTest *test);

static void
S_run_clash_tests(CFCTest *test);

const CFCTestBatch CFCTEST_BATCH_HIERARCHY = {
    "Clownfish::CFC::Model::Hierarchy",
    41,
    S_run_tests
};

static void
S_run_tests(CFCTest *test) {
    S_run_basic_tests(test);
    S_run_include_tests(test);
    S_run_clash_tests(test);
}

static void
S_run_basic_tests(CFCTest *test) {
    char *cfbase_path = CFCTest_path("cfbase");

    CFCHierarchy *hierarchy = CFCHierarchy_new(AUTOGEN);
    STR_EQ(test, CFCHierarchy_get_dest(hierarchy), AUTOGEN, "get_dest");
    STR_EQ(test, CFCHierarchy_get_include_dest(hierarchy), AUTOGEN_INCLUDE,
           "get_include_dest");
    STR_EQ(test, CFCHierarchy_get_source_dest(hierarchy), AUTOGEN_SOURCE,
           "get_source_dest");

    CFCHierarchy_add_source_dir(hierarchy, cfbase_path);
    const char **source_dirs = CFCHierarchy_get_source_dirs(hierarchy);
    STR_EQ(test, source_dirs[0], cfbase_path, "source_dirs[0]");
    OK(test, source_dirs[1] == NULL, "source_dirs[1]");

    CFCHierarchy_build(hierarchy);

    CFCFile **files  = CFCHierarchy_files(hierarchy);
    CFCFile  *animal = NULL;
    CFCFile  *dog    = NULL;
    CFCFile  *util   = NULL;
    for (int i = 0; i < 3; ++i) {
        CFCFile *file = files[i];
        OK(test, file != NULL, "files[%d]", i);
        OK(test, !CFCFile_get_modified(file), "start off not modified");

        CFCBase **blocks = CFCFile_blocks(file);
        for (int j = 0; blocks[j]; ++j) {
            CFCBase *block = blocks[j];
            const char *cfc_class_name = CFCBase_get_cfc_class(block);
            if (strcmp(cfc_class_name, "Clownfish::CFC::Model::Class") == 0) {
                CFCClass *klass = (CFCClass*)block;
                const char *class_name = CFCClass_get_name(klass);
                if (strcmp(class_name, "Animal") == 0) {
                    animal = file;
                }
                else if (strcmp(class_name, "Animal::Dog") == 0) {
                    dog = file;
                }
                else if (strcmp(class_name, "Animal::Util") == 0) {
                    util = file;
                }
            }
        }
    }
    OK(test, files[3] == NULL, "recursed and found all three files");

    {
        CFCClass **ordered_classes = CFCHierarchy_ordered_classes(hierarchy);
        OK(test, ordered_classes[0] != NULL, "ordered_classes[0]");
        OK(test, ordered_classes[1] != NULL, "ordered_classes[1]");
        OK(test, ordered_classes[2] != NULL, "ordered_classes[2]");
        OK(test, ordered_classes[3] != NULL, "ordered_classes[3]");
        OK(test, ordered_classes[4] == NULL, "all classes");
        FREEMEM(ordered_classes);
    }

    // Generate fake C files, with times set to two seconds ago.
    time_t now       = time(NULL);
    time_t past_time = now - 2;
    static const char *const h_paths[] = {
        AUTOGEN_INCLUDE CHY_DIR_SEP "Animal.h",
        AUTOGEN_INCLUDE CHY_DIR_SEP "Animal" CHY_DIR_SEP "Dog.h",
        AUTOGEN_INCLUDE CHY_DIR_SEP "Animal" CHY_DIR_SEP "Util.h"
    };
    for (int i = 0; i < 3; ++i) {
        const char *h_path  = h_paths[i];
        const char *content = "#include <stdio.h>\n";
        CFCUtil_write_file(h_path, content, strlen(content));
        CFCTest_set_file_times(h_path, past_time);
    }

    const char *cfh_path = CFCFile_get_path(animal);
    CFCTest_set_file_times(cfh_path, now);

    CFCHierarchy_propagate_modified(hierarchy, 0);

    OK(test, CFCFile_get_modified(animal), "Animal modified");
    OK(test, CFCFile_get_modified(dog),
       "Parent's modification propagates to child's file");
    OK(test, !CFCFile_get_modified(util),
       "Modification doesn't propagate to inert class");

    for (int i = 0; i < 3; ++i) {
        remove(h_paths[i]);
    }
    rmdir(AUTOGEN_INCLUDE CHY_DIR_SEP "Animal");
    rmdir(AUTOGEN_INCLUDE);
    rmdir(AUTOGEN_SOURCE);
    rmdir(AUTOGEN);

    CFCBase_decref((CFCBase*)hierarchy);
    FREEMEM(cfbase_path);
    CFCClass_clear_registry();
    CFCParcel_reap_singletons();
}

static void
S_run_include_tests(CFCTest *test) {
    char *cfbase_path = CFCTest_path("cfbase");
    char *cfext_path  = CFCTest_path("cfext");
    char *cfinc_path  = CFCTest_path("cfinc");

    {
        CFCHierarchy *hierarchy = CFCHierarchy_new(AUTOGEN);
        CFCHierarchy_add_source_dir(hierarchy, cfext_path);
        CFCHierarchy_add_include_dir(hierarchy, cfinc_path);
        const char **include_dirs = CFCHierarchy_get_include_dirs(hierarchy);
        STR_EQ(test, include_dirs[0], cfinc_path, "include_dirs[0]");
        OK(test, include_dirs[1] == NULL, "include_dirs[1]");

        CFCHierarchy_build(hierarchy);

        CFCClass **classes    = CFCHierarchy_ordered_classes(hierarchy);
        CFCClass  *rottweiler = NULL;;
        int num_classes;
        int num_source_classes = 0;
        for (num_classes = 0; classes[num_classes]; ++num_classes) {
            CFCClass *klass = classes[num_classes];
            int expect_included = 1;
            const char *class_name = CFCClass_get_name(klass);
            if (strcmp(class_name, "Animal::Rottweiler") == 0) {
                rottweiler      = klass;
                expect_included = 0;
                ++num_source_classes;
            }
            INT_EQ(test, CFCClass_included(klass), expect_included,
                   "included");
        }
        INT_EQ(test, num_classes, 5, "class count");
        INT_EQ(test, num_source_classes, 1, "source class count");
        STR_EQ(test, CFCClass_get_name(CFCClass_get_parent(rottweiler)),
               "Animal::Dog", "parent of included class");

        FREEMEM(classes);
        CFCBase_decref((CFCBase*)hierarchy);
        CFCClass_clear_registry();
        CFCParcel_reap_singletons();
    }

    {
        CFCHierarchy *hierarchy = CFCHierarchy_new(AUTOGEN);
        CFCHierarchy_add_source_dir(hierarchy, cfbase_path);
        CFCHierarchy_add_source_dir(hierarchy, cfext_path);

        CFCHierarchy_build(hierarchy);

        CFCClass **classes    = CFCHierarchy_ordered_classes(hierarchy);
        CFCClass  *rottweiler = NULL;;
        int num_classes;
        for (num_classes = 0; classes[num_classes]; ++num_classes) {
            CFCClass *klass = classes[num_classes];
            const char *class_name = CFCClass_get_name(klass);
            if (strcmp(class_name, "Animal::Rottweiler") == 0) {
                rottweiler = klass;
            }
            OK(test, !CFCClass_included(klass), "not included");
        }
        INT_EQ(test, num_classes, 5, "class count");
        OK(test, rottweiler != NULL, "found rottweiler");
        STR_EQ(test, CFCClass_get_name(CFCClass_get_parent(rottweiler)),
               "Animal::Dog", "parent of class from second source");

        FREEMEM(classes);
        CFCBase_decref((CFCBase*)hierarchy);
        CFCClass_clear_registry();
        CFCParcel_reap_singletons();
    }

    rmdir(AUTOGEN_INCLUDE);
    rmdir(AUTOGEN_SOURCE);
    rmdir(AUTOGEN);

    FREEMEM(cfbase_path);
    FREEMEM(cfext_path);
    FREEMEM(cfinc_path);
}

static void
S_run_clash_tests(CFCTest *test) {
    char *cfbase_path        = CFCTest_path("cfbase");
    char *cfinc_path         = CFCTest_path("cfinc");
    char *cfclash_file_path  = CFCTest_path("cfclash" CHY_DIR_SEP "file");
    char *cfclash_class_path = CFCTest_path("cfclash" CHY_DIR_SEP "class");
    char *cfclash_bar_path   = CFCTest_path("cfclash" CHY_DIR_SEP "bar");

    if (getenv("CLOWNFISH_VALGRIND")) {
        SKIP(test, 1, "Exceptions leak");
    }
    else {
        CFCHierarchy *hierarchy = CFCHierarchy_new(AUTOGEN);
        CFCHierarchy_add_source_dir(hierarchy, cfbase_path);
        CFCHierarchy_add_source_dir(hierarchy, cfclash_file_path);
        char *error;

        CFCUTIL_TRY {
            CFCHierarchy_build(hierarchy);
        }
        CFCUTIL_CATCH(error);
        OK(test, error && strstr(error, "found twice"),
           "source/source filename clash");

        CFCBase_decref((CFCBase*)hierarchy);
        CFCClass_clear_registry();
        CFCParcel_reap_singletons();
    }

    if (getenv("CLOWNFISH_VALGRIND")) {
        SKIP(test, 1, "Exceptions leak");
    }
    else {
        CFCHierarchy *hierarchy = CFCHierarchy_new(AUTOGEN);
        CFCHierarchy_add_source_dir(hierarchy, cfclash_class_path);
        CFCHierarchy_add_include_dir(hierarchy, cfinc_path);
        char *error;

        CFCUTIL_TRY {
            CFCHierarchy_build(hierarchy);
        }
        CFCUTIL_CATCH(error);
        OK(test, error && strstr(error, "Two classes with name"),
           "source/include class name clash");

        CFCBase_decref((CFCBase*)hierarchy);
        CFCClass_clear_registry();
        CFCParcel_reap_singletons();
    }

    if (getenv("CLOWNFISH_VALGRIND")) {
        SKIP(test, 1, "Exceptions leak");
    }
    else {
        CFCHierarchy *hierarchy = CFCHierarchy_new(AUTOGEN);
        CFCHierarchy_add_source_dir(hierarchy, cfclash_bar_path);
        CFCHierarchy_add_include_dir(hierarchy, cfinc_path);
        char *error;

        CFCUTIL_TRY {
            CFCHierarchy_build(hierarchy);
        }
        CFCUTIL_CATCH(error);
        const char *message =
            "Class Baz from source dir found in parcel Foo from include dir";
        OK(test, error && strstr(error, message),
           "source class with included parcel");

        CFCBase_decref((CFCBase*)hierarchy);
        CFCClass_clear_registry();
        CFCParcel_reap_singletons();
    }

    rmdir(AUTOGEN_INCLUDE);
    rmdir(AUTOGEN_SOURCE);
    rmdir(AUTOGEN);

    FREEMEM(cfbase_path);
    FREEMEM(cfinc_path);
    FREEMEM(cfclash_file_path);
    FREEMEM(cfclash_class_path);
    FREEMEM(cfclash_bar_path);
}

