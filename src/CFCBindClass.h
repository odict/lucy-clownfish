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

/** Clownfish::CFC::Binding::Core::Class - Generate core C code for a class.
 *
 * Clownfish::CFC::Model::Class is an abstract specification for a class.
 * This module autogenerates the C code with implements that specification.
 */

#ifndef H_CFCBINDCLASS
#define H_CFCBINDCLASS

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CFCBindClass CFCBindClass;

struct CFCClass;

/**
 * @param client A Clownfish::CFC::Model::Class.
 */
struct CFCBindClass*
CFCBindClass_new(struct CFCClass *client);

struct CFCBindClass*
CFCBindClass_init(struct CFCBindClass *self, struct CFCClass *client);

void
CFCBindClass_destroy(CFCBindClass *self);

/** Return the .h file which contains autogenerated C code defining the
 * class's interface: all method invocation functions, etc...
 */
char*
CFCBindClass_to_c_header(CFCBindClass *self);

/** Return the C data definitions necessary for the class to function properly.
 */
char*
CFCBindClass_to_c_data(CFCBindClass *self);

/** Return the autogenerated C definition of class's VTableSpec.
 */
char*
CFCBindClass_spec_def(CFCBindClass *self);

#ifdef __cplusplus
}
#endif

#endif /* H_CFCBINDCLASS */

