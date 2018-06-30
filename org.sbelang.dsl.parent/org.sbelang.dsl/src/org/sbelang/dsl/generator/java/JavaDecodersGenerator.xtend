/**
 * Copyright (C) by Alexandros Karypidis
 * Created on 22 Jun 2018
 */
package org.sbelang.dsl.generator.java

import java.io.File
import java.nio.file.Paths
import org.sbelang.dsl.generator.intermediate.FieldIndex
import org.sbelang.dsl.generator.intermediate.ParsedSchema
import org.sbelang.dsl.generator.intermediate.SbeUtils
import org.sbelang.dsl.sbeLangDsl.BlockDeclaration
import org.sbelang.dsl.sbeLangDsl.CompositeMember
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.FieldDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.PresenceConstantModifier
import org.sbelang.dsl.sbeLangDsl.SetChoiceDeclaration
import org.sbelang.dsl.sbeLangDsl.SetDeclaration
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration

/**
 * @author karypid
 * 
 */
class JavaDecodersGenerator {
    val ParsedSchema parsedSchema
    val String packagePath

    val JavaGeneratorExt extensions

    new(ParsedSchema parsedSchema, JavaGeneratorExt extensions) {
        this.parsedSchema = parsedSchema
        this.extensions = extensions

        this.packagePath = {
            val String[] components = parsedSchema.schemaName.split("\\.")
            val schemaPath = Paths.get(".", components)
            Paths.get(".").relativize(schemaPath).normalize.toString
        }
    }

    // -----------------------------------------------------------------------------
    // Code for generating set decoders
    // -----------------------------------------------------------------------------
    def generateSetDecoder(SetDeclaration sd) {
        val setName = sd.name.toFirstUpper
        val setDecoderName = setName + 'Decoder'
        val setEncodingOctetLength = SbeUtils.getPrimitiveTypeOctetLength(sd.encodingType)

        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.DirectBuffer;
            
            public class «setDecoderName»
            {
                public static final int ENCODED_LENGTH = «setEncodingOctetLength»;
                
                private DirectBuffer buffer;
                private int offset;
                
                public «setDecoderName» wrap( final DirectBuffer buffer, final int offset )
                {
                    this.buffer = buffer;
                    this.offset = offset;
                
                    return this;
                }
                
                public DirectBuffer buffer()
                {
                    return buffer;
                }
                
                public int offset()
                {
                    return offset;
                }
                
                public int encodedLength()
                {
                    return ENCODED_LENGTH;
                }
                
                «FOR setChoice : sd.setChoices»
                    // choice: «setChoice.name»
                    «generateSetChoiceDecoder(sd, setChoice)»
                    
                «ENDFOR»
            }
        '''
    }

    private def generateSetChoiceDecoder(SetDeclaration sd, SetChoiceDeclaration setChoice) {
        val setChoiceName = setChoice.name.toFirstLower
        val setJavaType = JavaGenerator.primitiveToJavaWireType(sd.encodingType)
        val getFetcher = 'get' + setJavaType.toFirstUpper
        val optionalEndian = endianParam(setJavaType)
        val constOne = if (setJavaType === 'long') '''1L''' else '''1'''
        val bitPos = setChoice.value

        '''
            public boolean «setChoiceName»()
            {
                return 0 !=  ( buffer.«getFetcher»( offset«optionalEndian» ) & («constOne» << «bitPos») );
            }
            
            public static boolean «setChoiceName»( final «setJavaType» value )
            {
                return 0 !=  ( value & («constOne» << «bitPos») );
            }
        '''
    }

    // -----------------------------------------------------------------------------
    // Code for generating composite decoders
    // -----------------------------------------------------------------------------
    def generateCompositeDecoder(CompositeTypeDeclaration ctd) {
        val decoderClassName = ctd.name.toFirstUpper + 'Decoder'
        val fieldIndex = parsedSchema.getCompositeFieldIndex(ctd.name)

        val classDeclarationInterfaces = if (extensions === null) '''''' else extensions.
                decoderClassDeclarationExtensions(decoderClassName)

        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.DirectBuffer;
            
            public class «decoderClassName»«classDeclarationInterfaces»
            {
                public static final int ENCODED_LENGTH = «fieldIndex.totalOctetLength»;
                
                private int offset;
                private DirectBuffer buffer;
                
                public «decoderClassName» wrap( final DirectBuffer buffer, final int offset )
                {
                    this.buffer = buffer;
                    this.offset = offset;
                    
                    return this;
                }
                
                public DirectBuffer buffer()
                {
                    return buffer;
                }
                
                public int offset()
                {
                    return offset;
                }
                
                public int encodedLength()
                {
                    return ENCODED_LENGTH;
                }
                
                «FOR cm : ctd.compositeMembers»
                    «generateComposite_CompositeMember_Decoder(ctd, cm)»
                «ENDFOR»
            }
        '''
    }

    private def generateComposite_CompositeMember_Decoder(CompositeTypeDeclaration ownerComposite,
        CompositeMember member) {
        switch member {
            MemberRefTypeDeclaration: {
                val memberVarName = member.name.toFirstLower
                val ownerCompositeDecoderClass = ownerComposite.name.toFirstUpper + 'Decoder'
                val fieldIndex = parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                val fieldOffset = fieldIndex.getOffset(member.name)
                val fieldOctetLength = fieldIndex.getOctectLength(member.name)
                val presence = member.presence
                val constLiteral = if (presence instanceof PresenceConstantModifier) {
                        presence.constantValue
                    } else
                        null

                if (member.primitiveType !== null) {
                    val arrayLength = if(member.length === null) 1 else member.length
                    generateDecoderCodeForPrimitiveData(ownerCompositeDecoderClass, memberVarName,
                        member.primitiveType, fieldOffset, fieldOctetLength, arrayLength, constLiteral)
                } else if (member.type !== null) {
                    val memberType = member.type
                    switch memberType {
                        SimpleTypeDeclaration: {
                            val arrayLength = if(memberType.length === null) 1 else memberType.length
                            generateDecoderCodeForPrimitiveData(ownerCompositeDecoderClass, memberVarName,
                                memberType.primitiveType, fieldOffset, fieldOctetLength, arrayLength, constLiteral)
                        }
                        EnumDeclaration:
                            generateDecoderCodeForEnumerationData(
                                ownerComposite.name,
                                memberType,
                                member.name.toFirstLower,
                                parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                            )
                        SetDeclaration:
                            generateDecoderCodeForSetData(
                                memberType,
                                member.name.toFirstLower,
                                parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                            )
                        CompositeTypeDeclaration:
                            generateDecoderCodeForCompositeData(
                                memberType,
                                member.name.toFirstLower,
                                parsedSchema.getCompositeFieldIndex(ownerComposite.name)
                            )
                        default: ''' /* TODO: reference to non-primitive - «member.toString» : «memberType.name» «memberType.class.name» */'''
                    }
                } else
                    ''' /* TODO: «member.toString» */'''
            }
            // all inline declarations below --------------------
            CompositeTypeDeclaration:
                generateDecoderCodeForCompositeData(member, member.name.toFirstLower,
                    parsedSchema.getCompositeFieldIndex(ownerComposite.name))
            EnumDeclaration:
                generateDecoderCodeForEnumerationData(ownerComposite.name, member, member.name.toFirstLower,
                    parsedSchema.getCompositeFieldIndex(ownerComposite.name))
            SetDeclaration:
                generateDecoderCodeForSetData(member, member.name.toFirstLower,
                    parsedSchema.getCompositeFieldIndex(ownerComposite.name))
            default: {
                ''' /* NOT IMPLEMENTED YET: «member.toString» */'''
            }
        }
    }

    // -----------------------------------------------------------------------------
    // Code for generating message decoders
    // -----------------------------------------------------------------------------
    def generateMessageDecoder(BlockDeclaration block) {
        val decoderClassName = block.name.toFirstUpper + 'Decoder'
        val fieldIndex = parsedSchema.getBlockFieldIndex(block.name)

        val classDeclarationInterfaces = if (extensions === null) '''''' else extensions.
                encoderClassDeclarationExtensions(decoderClassName)

        '''
            package  «parsedSchema.schemaName»;
            
            import org.agrona.MutableDirectBuffer;
            
            public class «decoderClassName»«classDeclarationInterfaces»
            {
                public static final int TEMPLATE_ID = «block.id»;
                public static final int BLOCK_LENGTH = «fieldIndex.totalOctetLength»;
                
                private MutableDirectBuffer buffer;
                private int offset;
                private int limit;
                
                public int sbeBlockLength()
                {
                    return BLOCK_LENGTH;
                }
                
                public int sbeTemplateId()
                {
                    return TEMPLATE_ID;
                }
                
                public int sbeSchemaId()
                {
                    return MessageSchema.SCHEMA_ID;
                }
                
                public int sbeSchemaVersion()
                {
                    return MessageSchema.SCHEMA_VERSION;
                }
                
                public «decoderClassName» wrap( final MutableDirectBuffer buffer, final int offset )
                {
                    this.buffer = buffer;
                    this.offset = offset;
                    
                    return this;
                }
                
                public MutableDirectBuffer buffer()
                {
                    return buffer;
                }
                
                public int offset()
                {
                    return offset;
                }
                
                public int encodedLength()
                {
                    return limit - offset;
                }
                
                public int limit()
                {
                    return limit;
                }
                
                public void limit(final int limit)
                {
                    this.limit = limit;
                }
                
                «FOR field : block.fieldDeclarations»
                    «generateDecoderForBlockField(block, field)»
                «ENDFOR»
            }
        '''
    }

    private def generateDecoderForBlockField(BlockDeclaration block, FieldDeclaration field) {
        val fieldIndex = parsedSchema.getBlockFieldIndex(block.name)

        if (field.primitiveType !== null) {
            val presence = field.presence
            val constLiteral = if (presence instanceof PresenceConstantModifier) {
                    presence.constantValue
                } else
                    null
            return generateDecoderCodeForPrimitiveData(
                block.name.toFirstUpper + "Decoder",
                field.name,
                field.primitiveType,
                fieldIndex.getOffset(field.name),
                fieldIndex.getOctectLength(field.name),
                /* Fixed array length of ONE because fields can't have length */ 1,
                constLiteral
            )
        }

        val type = field.type

        switch type {
            SimpleTypeDeclaration: {
                val arrayLength = if(type.length === null) 1 else type.length
                val presence = field.presence
                val constLiteral = if (presence instanceof PresenceConstantModifier) {
                        presence.constantValue
                    } else
                        null
                generateDecoderCodeForPrimitiveData(
                    block.name.toFirstUpper + "Decoder",
                    field.name,
                    type.primitiveType,
                    fieldIndex.getOffset(field.name),
                    fieldIndex.getOctectLength(field.name),
                    arrayLength,
                    constLiteral
                )
            }
            EnumDeclaration:
                generateDecoderCodeForEnumerationData(
                    block.name,
                    type,
                    field.name.toFirstLower,
                    parsedSchema.getBlockFieldIndex(block.name)
                )
            SetDeclaration:
                generateDecoderCodeForSetData(type, field.name.toFirstLower,
                    parsedSchema.getBlockFieldIndex(block.name))
            CompositeTypeDeclaration:
                generateDecoderCodeForCompositeData(type, field.name.toFirstLower,
                    parsedSchema.getBlockFieldIndex(block.name))
            default: '''// TODO: ???? - «field.name» : «type.name»'''
        }
    }

    // -----------------------------------------------------------------------------
    // Common code fragment templates used for both composites and  blocks
    // -----------------------------------------------------------------------------
    private def generateDecoderCodeForPrimitiveData(String ownerCompositeDecoderClass, String memberVarName,
        String sbePrimitiveType, int fieldOffset, int fieldOctetLength, int arrayLength, String constLiteral) {
        val memberValueParamType = JavaGenerator.primitiveToJavaDataType(sbePrimitiveType)
        val memberValueWireType = JavaGenerator.primitiveToJavaWireType(sbePrimitiveType)
        val getFetcher = 'get' + memberValueWireType.toFirstUpper
        val optionalEndian = endianParam(memberValueWireType)
        val fieldElementLength = SbeUtils.getPrimitiveTypeOctetLength(sbePrimitiveType)

        val constantLiteral = if (constLiteral === null)
                null
            else
                JavaGenerator.javaLiteral(sbePrimitiveType, constLiteral)

        val defaultCode = '''
            // «memberVarName»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldOctetLength»;
            }
            
            «IF constantLiteral !== null»
                public «memberValueParamType» «memberVarName»()
                {
                    return «constantLiteral»;
                }
            «ELSEIF arrayLength <= 1»
                public «memberValueParamType» «memberVarName»()
                {
                    return buffer.«getFetcher»( offset + «fieldOffset» «optionalEndian»);
                }
            «ELSE»
                public static int «memberVarName»Length()
                {
                    return «arrayLength»;
                }
                
                public «memberValueParamType» «memberVarName»( final int index )
                {
                    if (index < 0 || index >= «arrayLength»)
                    {
                        throw new IndexOutOfBoundsException("index out of range: index=" + index);
                    }
                    
                    final int pos = this.offset + «fieldOffset» + (index * «fieldElementLength»);
                    return buffer.«getFetcher»(pos «optionalEndian»);
                }
                «IF sbePrimitiveType == 'char'»
                    
                    public int get«memberVarName.toFirstUpper»( final byte[] dst, final int dstOffset )
                    {
                        final int length = «arrayLength»;
                        if (dstOffset < 0 || dstOffset > (dst.length - length))
                        {
                            throw new IndexOutOfBoundsException("Copy will go out of range: offset=" + dstOffset);
                        }
                        
                        buffer.getBytes(this.offset + «fieldOffset», dst, dstOffset, length);
                        
                        return length;
                    }
                «ENDIF»
            «ENDIF»
            
        '''

        if (extensions === null)
            defaultCode
        else {
            extensions.generateDecoderCodeForPrimitiveData(ownerCompositeDecoderClass, memberVarName, sbePrimitiveType,
                fieldOffset, fieldOctetLength, arrayLength, constantLiteral, defaultCode)
        }
    }

    private def generateDecoderCodeForEnumerationData(String ownerName, EnumDeclaration enumMember,
        String memberVarName, FieldIndex fieldIndex) {

        val fieldOffset = fieldIndex.getOffset(enumMember.name)

        val memberEnumType = enumMember.name.toFirstUpper
        val memberEnumJavaWireType = JavaGenerator.primitiveToJavaWireType(enumMember.encodingType)
        val memberEnumJavaDataType = JavaGenerator.primitiveToJavaDataType(enumMember.encodingType)
        val getFetcher = 'get' + memberEnumJavaWireType.toFirstUpper
        val optionalEndian = endianParam(memberEnumJavaWireType)

        val mask = enumAllBitsMask(enumMember.encodingType)
        val maskStart = if (mask == '') '''''' else '''('''
        val maskEnd = if (mask == '') '''''' else ''' & «mask»)'''

        val cast = if (memberEnumJavaWireType !== memberEnumJavaDataType) '''(«memberEnumJavaDataType»)'''

        '''
            // «enumMember.name»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldIndex.getOctectLength(enumMember.name)»;
            }
            
            public «memberEnumType» «memberVarName»()
            {
                return «memberEnumType».get( «cast» «maskStart»buffer.«getFetcher»( offset + «fieldOffset»«optionalEndian»)«maskEnd» );
            }
            
        '''
    }

    private def generateDecoderCodeForSetData(SetDeclaration setMember, String memberVarName, FieldIndex fieldIndex) {
        val setDecoderClassName = setMember.name.toFirstUpper + 'Decoder'
        val fieldOffset = fieldIndex.getOffset(setMember.name)

        '''
            // «setMember.name»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldIndex.getOctectLength(setMember.name)»;
            }
            
            private final «setDecoderClassName» «memberVarName» = new «setDecoderClassName»();
            
            public «setDecoderClassName» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset»);
                return «memberVarName»;
            }
            
        '''
    }

    private def generateDecoderCodeForCompositeData(CompositeTypeDeclaration member, String memberVarName,
        FieldIndex fieldIndex) {

        val memberDecoderClass = member.name.toFirstUpper + 'Decoder'
        val fieldOffset = fieldIndex.getOffset(memberVarName)
        val fieldEncodingLength = fieldIndex.getOctectLength(memberVarName)

        '''
            // «memberDecoderClass»
            public static int «memberVarName»EncodingOffset()
            {
                return «fieldOffset»;
            }
            
            public static int «memberVarName»EncodingLength()
            {
                return «fieldEncodingLength»;
            }
            
            private «memberDecoderClass» «memberVarName» = new «memberDecoderClass»();
            
            public «memberDecoderClass» «memberVarName»()
            {
                «memberVarName».wrap(buffer, offset + «fieldOffset» );
                return «memberVarName»;
            }
            
        '''
    }

    // java utils ----------------------------------------------------
    private def endianParam(String primitiveJavaType) {
        if (primitiveJavaType == 'byte') '''''' else ''', java.nio.ByteOrder.«parsedSchema.schemaByteOrder»'''
    }

    private def enumAllBitsMask(String sbeEnumEncodingType) {
        switch (sbeEnumEncodingType) {
            case 'char':
                ''
            case 'uint8':
                '0xFF'
            case 'uint16':
                '0xFFFF'
            default:
                throw new IllegalStateException('Why would you need this? Enums should not be of type: ' +
                    sbeEnumEncodingType)
        }
    }

    // other utils ---------------------------------------------------
    def filename(String filename) {
        packagePath.toString + File.separatorChar + filename
    }

}
