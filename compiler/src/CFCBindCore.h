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

/** Clownfish::CFC::Binding::Core - Generate core C code for a
 * Clownfish::CFC::Model::Hierarchy.
 *
 * A Clownfish::CFC::Model::Hierarchy describes an abstract specifiction for a
 * class hierarchy; Clownfish::CFC::Binding::Core is responsible for
 * auto-generating C code which implements that specification.
 */
#ifndef H_CFCBINDCORE
#define H_CFCBINDCORE

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CFCBindCore CFCBindCore;
struct CFCHierarchy;


/**
 * @param hierarchy A L<Clownfish::CFC::Model::Hierarchy>.
 * @param header Text which will be prepended to each generated C file --
 * typically, an "autogenerated file" warning.
 * @param footer Text to be appended to the end of each generated C file --
 * typically copyright information.
 * @param charmonic If true, make cfish_platform.h include charmony.h.
 * Otherwise, use the same config CFC was compiled with.
 */
CFCBindCore*
CFCBindCore_new(struct CFCHierarchy *hierarchy, const char *header,
                const char *footer, int charmonic);

CFCBindCore*
CFCBindCore_init(CFCBindCore *self, struct CFCHierarchy *hierarchy,
                 const char *header, const char *footer, int charmonic);

void
CFCBindCore_destroy(CFCBindCore *self);

/** Call `CFCHierarchy_propagate_modified`to establish which
 * classes do not have up-to-date generated .c and .h files, then traverse the
 * hierarchy writing all necessary files.
 */
int
CFCBindCore_write_all_modified(CFCBindCore *self, int modified);

/** Copy .cfh and .cfp files for installed source parcels to the autogen
 * directory.
 *
 * @param dest_dir Destination directory. Defaults to
 * `autogen/share/clownfish/include` if NULL.
 */
void
CFCBindCore_copy_headers(CFCBindCore *self, const char *dest_dir);

/* Write host-specific data to a JSON file for each source parcel.
 */
void
CFCBindCore_write_host_data_json(CFCBindCore *self, const char *dest_dir,
                                 const char *host_lang);

#ifdef __cplusplus
}
#endif

#endif /* H_CFCBINDCORE */


