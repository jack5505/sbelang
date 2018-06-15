/*
 * generated by Xtext 2.13.0
 */
package org.sbelang.dsl.validation

import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.validation.Check
import org.sbelang.dsl.SbeLangDslValueUtils
import org.sbelang.dsl.sbeLangDsl.CompositeTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.EnumDeclaration
import org.sbelang.dsl.sbeLangDsl.FieldDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberPrimitiveTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MemberRefTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.MessageSchema
import org.sbelang.dsl.sbeLangDsl.PresenceConstantModifier
import org.sbelang.dsl.sbeLangDsl.PresenceModifiers
import org.sbelang.dsl.sbeLangDsl.SbeLangDslPackage
import org.sbelang.dsl.sbeLangDsl.SetDeclaration
import org.sbelang.dsl.sbeLangDsl.SimpleTypeDeclaration
import org.sbelang.dsl.sbeLangDsl.TypeDeclaration
import org.sbelang.dsl.sbeLangDsl.VersionModifiers

import static org.sbelang.dsl.SbeLangDslValueUtils.isValidLiteral

/**
 * This class contains custom validation rules. 
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class SbeLangDslValidator extends AbstractSbeLangDslValidator {

    public static val CHAR_PRIMITIVE = 'char'

    @Check
    def checkAllTypeNamesAreUnique(MessageSchema messageSchema) {
        validateAllTypeNamesAreUnique(messageSchema.typeDelcarations.map[t|new NameDeclaration(t.name, t)],
            new HashMap<String, EObject>())
    }

    @Check
    def checkField(FieldDeclaration fd) {
        val type = fd.fieldType
        val presence = fd.presenceModifiers
        validatePresence(presence, type)
    }

    @Check
    def checkMemberType(MemberPrimitiveTypeDeclaration mtd) {
        switch mtd.presence {
            PresenceConstantModifier:
                validatePresenceConstant(mtd.presence as PresenceConstantModifier, mtd.primitiveType)
        }
    }

    @Check
    def checkSet(SetDeclaration sd) {
        var idx = 0
        val maxValidBitIdx = switch (sd.encodingType) {
            case 'uint8': 7
            case 'uint16': 15
            case 'uint32': 31
            case 'uint64': 63
            default: -1
        }

        for (choice : sd.setChoices) {
            if ((choice.value < 0) || (choice.value > maxValidBitIdx))
                error(
                    '''Value is [«choice.value»] is ousid the valid range of [0,«maxValidBitIdx»] for «sd.encodingType»!''',
                    sd,
                    SbeLangDslPackage.Literals.SET_DECLARATION__SET_CHOICES,
                    idx
                )

            idx = idx + 1
        }
    }

    @Check
    def checkEnum(EnumDeclaration ed) {
        var idx = 0
        for (ev : ed.enumValues) {
            if (!isValidLiteral(ev.value, ed.encodingType)) {
                error(
                    '''Value is [«ev.value»] which is outside the valid range for encoding typ [«ed.encodingType»]!''',
                    ev,
                    SbeLangDslPackage.Literals.ENUM_VALUE_DECLARATION__VALUE,
                    idx
                )
                idx = idx + 1
            }
        }
    }

    @Check
    def checkRangeIsProper(MemberPrimitiveTypeDeclaration mptd) {
        if(mptd.rangeModifiers === null) return; // no range can't be wrong
        if (mptd.presence !== null) {
            // if constant, range does not make sense...
            if (mptd.presence instanceof PresenceConstantModifier)
                error(
                    "You can't specify a range for a constant!",
                    SbeLangDslPackage.Literals.MEMBER_PRIMITIVE_TYPE_DECLARATION__RANGE_MODIFIERS
                )
        }

        if ((mptd.rangeModifiers.min !== null) && (mptd.rangeModifiers.max !== null)) {
            switch (mptd.primitiveType) {
                case 'char': {
                    val min = SbeLangDslValueUtils.parseCharacter(mptd.rangeModifiers.min)
                    val max = SbeLangDslValueUtils.parseCharacter(mptd.rangeModifiers.max)

                    if (min.isPresent && max.isPresent)
                        if (min.get.compareTo(max.get) > 0)
                            error(
                                '''Minimum range of («mptd.rangeModifiers.min») cannot exceed maximum of («mptd.rangeModifiers.max»)''',
                                SbeLangDslPackage.Literals.MEMBER_PRIMITIVE_TYPE_DECLARATION__RANGE_MODIFIERS
                            )
                }
                default: { // assume number...
                    val min = SbeLangDslValueUtils.parseBigDecimal(mptd.rangeModifiers.min)
                    val max = SbeLangDslValueUtils.parseBigDecimal(mptd.rangeModifiers.max)
                    if (min.isPresent && max.isPresent)
                        if (min.get.compareTo(max.get) > 0)
                            error(
                                '''Minimum range of («mptd.rangeModifiers.min») cannot exceed maximum of («mptd.rangeModifiers.max»)''',
                                SbeLangDslPackage.Literals.MEMBER_PRIMITIVE_TYPE_DECLARATION__RANGE_MODIFIERS
                            )
                }
            }
        }

        if (!isValidLiteral(mptd.rangeModifiers.min.toString, mptd.primitiveType)) {
            error(
                '''Minimum range of («mptd.rangeModifiers.min») is not within range of type («mptd.primitiveType»)''',
                SbeLangDslPackage.Literals.MEMBER_PRIMITIVE_TYPE_DECLARATION__RANGE_MODIFIERS
            )
        }

        if (!isValidLiteral(mptd.rangeModifiers.max.toString, mptd.primitiveType)) {
            error(
                '''Maximum range of («mptd.rangeModifiers.max») is not within range of type («mptd.primitiveType»)''',
                SbeLangDslPackage.Literals.MEMBER_PRIMITIVE_TYPE_DECLARATION__RANGE_MODIFIERS
            )
        }
    }

    @Check
    def checkVersionModifiers(VersionModifiers vm) {
        if (vm.sinceVersion !== null) {
            val ms = EcoreUtil.getRootContainer(vm) as MessageSchema

            if (vm.sinceVersion > ms.schema.version) {
                error(
                    '''The sinceVersion(«vm.sinceVersion») value cannot be greater than the schema version(«ms.schema.version») value!''',
                    vm,
                    SbeLangDslPackage.Literals.VERSION_MODIFIERS__DEPRECATED_SINCE_VERSION
                )
            }

            if (vm.deprecatedSinceVersion !== null) {
                if (vm.deprecatedSinceVersion > ms.schema.version) {
                    error(
                        '''The deprecatedSinceVersion(«vm.deprecatedSinceVersion») value cannot be greater than the schema version(«ms.schema.version») value!''',
                        vm,
                        SbeLangDslPackage.Literals.VERSION_MODIFIERS__DEPRECATED_SINCE_VERSION
                    )
                }

                if (vm.deprecatedSinceVersion <= vm.sinceVersion) {
                    error(
                        '''The deprecatedSinceVersion(«vm.deprecatedSinceVersion») value must be greater than the since version(«vm.sinceVersion») value!''',
                        vm,
                        SbeLangDslPackage.Literals.VERSION_MODIFIERS__DEPRECATED_SINCE_VERSION
                    )
                }
            }
        }
    }

    // INTERNALS ------------------------------------------------------

    private def validatePresence(PresenceModifiers presenceModifiers, TypeDeclaration typeDeclaration) {
        switch (presenceModifiers) {
            PresenceConstantModifier:
                validatePresenceConstant(presenceModifiers, typeDeclaration)
        // TODO: PresenceOptionalModifier: any validation required for this?
        }
    }

    private def validatePresenceConstant(PresenceConstantModifier constantModifier, TypeDeclaration typeDeclaration) {
        switch typeDeclaration {
            SimpleTypeDeclaration:
                validatePresenceConstant(constantModifier, typeDeclaration.primitiveType)
//            EnumDeclaration:
//            SetDeclaration:
//            CompositeTypeDeclaration:
        }
    }

    private def validatePresenceConstant(PresenceConstantModifier constantModifier, String primitiveType) {
        if (! isValidLiteral(constantModifier.constantValue, primitiveType)) {
            error('''The value [«constantModifier.constantValue»] is not valid for the type [«primitiveType»]''',
                constantModifier, SbeLangDslPackage.Literals.PRESENCE_CONSTANT_MODIFIER__CONSTANT_VALUE)
        }
    }

    private static class NameDeclaration {
        String name;
        EObject declaringObject;

        new(String n, EObject o) {
            this.name = n
            this.declaringObject = o
        }
    }
    
    private def void validateAllTypeNamesAreUnique(List<NameDeclaration> nameDeclarations, Map<String, EObject> names) {
        nameDeclarations.forEach [ nd |
            val existing = names.put(nd.name, nd.declaringObject)
            if (existing !== null) {
                val existingNode = NodeModelUtils.getNode(existing)
                val featureId = switch nd.declaringObject {
                    MemberPrimitiveTypeDeclaration:
                        SbeLangDslPackage.Literals.MEMBER_PRIMITIVE_TYPE_DECLARATION__NAME
                    default: // all others are descendants of type declaration
                        SbeLangDslPackage.Literals.TYPE_DECLARATION__NAME
                }
                error(
                    '''Duplicate (case-insensitive) name [«nd.name»]; previous declaration at line «existingNode.startLine»''',
                    nd.declaringObject,
                    featureId
                )
            }
            if (nd.declaringObject instanceof CompositeTypeDeclaration) {
                val composite = nd.declaringObject as CompositeTypeDeclaration
                validateAllTypeNamesAreUnique(composite.compositeMembers.map [ cm |
                    switch cm {
                        MemberPrimitiveTypeDeclaration:
                            new NameDeclaration(cm.name, cm)
                        MemberRefTypeDeclaration:
                            new NameDeclaration(cm.name, cm)
                        SetDeclaration:
                            new NameDeclaration(cm.name, cm)
                        EnumDeclaration:
                            new NameDeclaration(cm.name, cm)
                        CompositeTypeDeclaration:
                            new NameDeclaration(cm.name, cm)
                    }
                ], names)
            }
        ]
    }

}
