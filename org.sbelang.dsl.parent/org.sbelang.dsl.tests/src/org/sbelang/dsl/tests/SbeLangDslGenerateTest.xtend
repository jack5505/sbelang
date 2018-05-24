/*
 * generated by Xtext 2.13.0
 */
package org.sbelang.dsl.tests

import com.google.inject.Injector
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith
import org.sbelang.dsl.SbeLangDslStandaloneSetup
import org.sbelang.dsl.generator.SbeLangDslXmlGenerator
import org.sbelang.dsl.generator.SbeLangDslJavaGenerator

@RunWith(XtextRunner)
@InjectWith(SbeLangDslInjectorProvider)
class SbeLangDslGenerateTest {
    @Test
    def void testXmlGenerate() {
        val Injector injector = new SbeLangDslStandaloneSetup().createInjectorAndDoEMFRegistration()
        val XtextResourceSet resourceSet = injector.getInstance(XtextResourceSet);
        val Resource resource = resourceSet.getResource(URI.createURI("resources/Examples.sbelang"), true);

        val InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess
        val IGeneratorContext ctx = new GeneratorContext

        val SbeLangDslXmlGenerator g = new SbeLangDslXmlGenerator
        g.beforeGenerate(resource, fsa, ctx)
        g.doGenerate(resource, fsa, ctx)
        g.afterGenerate(resource, fsa, ctx)
        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "Examples.sbelang.xml"))
    }

    @Test
    def void testJavaGenerate() {
        val Injector injector = new SbeLangDslStandaloneSetup().createInjectorAndDoEMFRegistration()
        val XtextResourceSet resourceSet = injector.getInstance(XtextResourceSet);
        val Resource resource = resourceSet.getResource(URI.createURI("resources/Examples.sbelang"), true);

        val InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess
        val IGeneratorContext ctx = new GeneratorContext

        val SbeLangDslJavaGenerator g = new SbeLangDslJavaGenerator
        g.beforeGenerate(resource, fsa, ctx)
        g.doGenerate(resource, fsa, ctx)
        g.afterGenerate(resource, fsa, ctx)

//        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "org/Examples/v0/Protocol.java"))
        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "org/Examples/v0/DATAEncoder.java"))
        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "org/Examples/v0/MONTH_YEAREncoder.java"))
        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "org/Examples/v0/OptionalDecimalEncodingEncoder.java"))
        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "org/Examples/v0/MessageHeaderEncoder.java"))
        System.out.println(fsa.textFiles.get(IFileSystemAccess.DEFAULT_OUTPUT + "org/Examples/v0/BusinessMessageRejectEncoder.java"))
    }
}
