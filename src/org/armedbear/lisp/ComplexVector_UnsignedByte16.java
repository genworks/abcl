/*
 * ComplexVector_UnsignedByte16.java
 *
 * Copyright (C) 2002-2005 Peter Graves
 * Copyright (C) 2026 David John Cooper
 * $Id$
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * As a special exception, the copyright holders of this library give you
 * permission to link this library with independent modules to produce an
 * executable, regardless of the license terms of these independent
 * modules, and to copy and distribute the resulting executable under
 * terms of your choice, provided that you also meet, for each linked
 * independent module, the terms and conditions of the license of that
 * module.  An independent module is a module which is not derived from
 * or based on this library.  If you modify this library, you may extend
 * this exception to your version of the library, but you are not
 * obligated to do so.  If you do not wish to do so, delete this
 * exception statement from your version.
 */

package org.armedbear.lisp;

import static org.armedbear.lisp.Lisp.*;

import org.armedbear.lisp.Java.Buffers.AllocationPolicy;

// A specialized vector of element type (UNSIGNED-BYTE 16) that is displaced to
// another array, has a fill pointer, and/or is expressly adjustable.  Modeled
// on ComplexVector_UnsignedByte8; one class serves both allocation policies,
// as there is no buffer-backed complex vector of this element type.
public final class ComplexVector_UnsignedByte16 extends AbstractVector
{
    private int capacity;
    private int fillPointer = -1; // -1 indicates no fill pointer.
    private boolean isDisplaced;

    // For non-displaced arrays.
    private char[] elements;

    // For displaced arrays.
    private AbstractArray array;
    private int displacement;

    public ComplexVector_UnsignedByte16(int capacity)
    {
        elements = new char[capacity];
        this.capacity = capacity;
    }

    public ComplexVector_UnsignedByte16(int capacity, AbstractArray array,
                                        int displacement)
    {
        this.capacity = capacity;
        this.array = array;
        this.displacement = displacement;
        isDisplaced = true;
    }

    // An element as the char that holds it: a TYPE-ERROR for anything
    // that is not an (UNSIGNED-BYTE 16).
    private static char toElement(LispObject obj)
    {
        if (obj instanceof Fixnum)
            return toElement(((Fixnum) obj).value);
        type_error(obj, UNSIGNED_BYTE_16);
        return 0; // Not reached.
    }

    private static char toElement(int n)
    {
        if (n < 0 || n > 65535)
            type_error(Fixnum.getInstance(n), UNSIGNED_BYTE_16);
        return (char) n;
    }

    // A simple vector of this element type under the active policy, as
    // MAKE-ARRAY makes it.
    private static AbstractVector newSimpleVector(int length)
    {
        if (Java.Buffers.active.equals(AllocationPolicy.NIO))
            return new BasicVector_CharBuffer(length);
        return new BasicVector_UnsignedByte16(length);
    }

    @Override
    public LispObject typeOf()
    {
        return list(Symbol.VECTOR, UNSIGNED_BYTE_16, Fixnum.getInstance(capacity));
    }

    @Override
    public LispObject classOf()
    {
        return BuiltInClass.VECTOR;
    }

    @Override
    public boolean hasFillPointer()
    {
        return fillPointer >= 0;
    }

    @Override
    public int getFillPointer()
    {
        return fillPointer;
    }

    @Override
    public void setFillPointer(int n)
    {
        fillPointer = n;
    }

    @Override
    public void setFillPointer(LispObject obj)
    {
        if (obj == T)
            fillPointer = capacity();
        else {
            int n = Fixnum.getValue(obj);
            if (n > capacity()) {
                StringBuffer sb = new StringBuffer("The new fill pointer (");
                sb.append(n);
                sb.append(") exceeds the capacity of the vector (");
                sb.append(capacity());
                sb.append(").");
                error(new LispError(sb.toString()));
            } else if (n < 0) {
                StringBuffer sb = new StringBuffer("The new fill pointer (");
                sb.append(n);
                sb.append(") is negative.");
                error(new LispError(sb.toString()));
            } else
                fillPointer = n;
        }
    }

    @Override
    public boolean isDisplaced()
    {
        return isDisplaced;
    }

    @Override
    public LispObject arrayDisplacement()
    {
        LispObject value1, value2;
        if (array != null) {
            value1 = array;
            value2 = Fixnum.getInstance(displacement);
        } else {
            value1 = NIL;
            value2 = Fixnum.ZERO;
        }
        return LispThread.currentThread().setValues(value1, value2);
    }

    @Override
    public LispObject getElementType()
    {
        return UNSIGNED_BYTE_16;
    }

    @Override
    public boolean isSimpleVector()
    {
        return false;
    }

    @Override
    public int capacity()
    {
        return capacity;
    }

    @Override
    public int length()
    {
        return fillPointer >= 0 ? fillPointer : capacity;
    }

    @Override
    public LispObject elt(int index)
    {
        final int limit = length();
        if (index < 0 || index >= limit)
            badIndex(index, limit);
        return AREF(index);
    }

    // Ignores fill pointer.
    @Override
    public LispObject AREF(int index)
    {
        if (elements != null) {
            try {
                return Fixnum.getInstance(elements[index]);
            }
            catch (ArrayIndexOutOfBoundsException e) {
                badIndex(index, elements.length);
                return NIL; // Not reached.
            }
        } else {
            // Displaced array.
            if (index < 0 || index >= capacity)
                badIndex(index, capacity);
            return array.AREF(index + displacement);
        }
    }

    @Override
    public void aset(int index, int n)
    {
        if (elements != null) {
            try {
                elements[index] = toElement(n);
            }
            catch (ArrayIndexOutOfBoundsException e) {
                badIndex(index, elements.length);
            }
        } else {
            // Displaced array.
            if (index < 0 || index >= capacity)
                badIndex(index, capacity);
            else
                array.aset(index + displacement, toElement(n));
        }
    }

    @Override
    public void aset(int index, LispObject newValue)
    {
        if (elements != null) {
            try {
                elements[index] = toElement(newValue);
            }
            catch (ArrayIndexOutOfBoundsException e) {
                badIndex(index, elements.length);
            }
        } else {
            // Displaced array: checked here, whatever the target takes.
            if (index < 0 || index >= capacity)
                badIndex(index, capacity);
            else {
                toElement(newValue);
                array.aset(index + displacement, newValue);
            }
        }
    }

    // A fresh simple vector of the same element type (CLHS SUBSEQ).
    @Override
    public LispObject subseq(int start, int end)
    {
        AbstractVector v = newSimpleVector(end - start);
        int i = start, j = 0;
        try {
            while (i < end)
                v.aset(j++, AREF(i++));
            return v;
        }
        catch (ArrayIndexOutOfBoundsException e) {
            return error(new TypeError("Array index out of bounds: " + i + "."));
        }
    }

    @Override
    public void fill(LispObject obj)
    {
        char c = toElement(obj);
        if (elements != null) {
            for (int i = capacity; i-- > 0;)
                elements[i] = c;
        } else {
            // Displaced array; obj is checked above.
            for (int i = 0; i < capacity; i++)
                array.aset(i + displacement, obj);
        }
    }

    @Override
    public void shrink(int n)
    {
        if (elements != null) {
            if (n < elements.length) {
                char[] newArray = new char[n];
                System.arraycopy(elements, 0, newArray, 0, n);
                elements = newArray;
                capacity = n;
                return;
            }
            if (n == elements.length)
                return;
        }
        error(new LispError());
    }

    @Override
    public LispObject reverse()
    {
        int length = length();
        AbstractVector result = newSimpleVector(length);
        int i, j;
        for (i = 0, j = length - 1; i < length; i++, j--)
            result.aset(i, AREF(j));
        return result;
    }

    @Override
    public LispObject nreverse()
    {
        if (elements != null) {
            int i = 0;
            int j = length() - 1;
            while (i < j) {
                char temp = elements[i];
                elements[i] = elements[j];
                elements[j] = temp;
                ++i;
                --j;
            }
        } else {
            // Displaced array.
            int length = length();
            char[] data = new char[length];
            int i, j;
            for (i = 0, j = length - 1; i < length; i++, j--)
                data[i] = toElement(AREF(j));
            elements = data;
            capacity = length;
            array = null;
            displacement = 0;
            isDisplaced = false;
            fillPointer = -1;
        }
        return this;
    }

    @Override
    public void vectorPushExtend(LispObject element)
    {
        if (fillPointer < 0)
            noFillPointer();
        if (fillPointer >= capacity) {
            // Need to extend vector.
            ensureCapacity(capacity * 2 + 1);
        }
        aset(fillPointer, element);
        ++fillPointer;
    }

    @Override
    public LispObject VECTOR_PUSH_EXTEND(LispObject element)
    {
        vectorPushExtend(element);
        return Fixnum.getInstance(fillPointer - 1);
    }

    @Override
    public LispObject VECTOR_PUSH_EXTEND(LispObject element, LispObject extension)
    {
        int ext = Fixnum.getValue(extension);
        if (fillPointer < 0)
            noFillPointer();
        if (fillPointer >= capacity) {
            // Need to extend vector.
            ext = Math.max(ext, capacity + 1);
            ensureCapacity(capacity + ext);
        }
        aset(fillPointer, element);
        return Fixnum.getInstance(fillPointer++);
    }

    private final void ensureCapacity(int minCapacity)
    {
        if (elements != null) {
            if (capacity < minCapacity) {
                char[] newArray = new char[minCapacity];
                System.arraycopy(elements, 0, newArray, 0, capacity);
                elements = newArray;
                capacity = minCapacity;
            }
        } else {
            // Displaced array.
            Debug.assertTrue(array != null);
            if (capacity < minCapacity ||
                array.getTotalSize() - displacement < minCapacity)
            {
                // Copy array.
                elements = new char[minCapacity];
                final int limit =
                    Math.min(capacity, array.getTotalSize() - displacement);
                for (int i = 0; i < limit; i++)
                    elements[i] = toElement(array.AREF(displacement + i));
                capacity = minCapacity;
                array = null;
                displacement = 0;
                isDisplaced = false;
            }
        }
    }

    @Override
    public AbstractVector adjustArray(int newCapacity,
                                       LispObject initialElement,
                                       LispObject initialContents)
    {
        if (initialContents != null) {
            // "If INITIAL-CONTENTS is supplied, it is treated as for MAKE-
            // ARRAY. In this case none of the original contents of array
            // appears in the resulting array."
            char[] newElements = new char[newCapacity];
            if (initialContents.listp()) {
                LispObject list = initialContents;
                for (int i = 0; i < newCapacity; i++) {
                    newElements[i] = toElement(list.car());
                    list = list.cdr();
                }
            } else if (initialContents.vectorp()) {
                for (int i = 0; i < newCapacity; i++)
                    newElements[i] = toElement(initialContents.elt(i));
            } else
                type_error(initialContents, Symbol.SEQUENCE);
            elements = newElements;
        } else {
            if (elements == null) {
                // Displaced array. Copy existing elements.
                elements = new char[newCapacity];
                final int limit = Math.min(capacity, newCapacity);
                for (int i = 0; i < limit; i++)
                    elements[i] = toElement(array.AREF(displacement + i));
            } else if (capacity != newCapacity) {
                char[] newElements = new char[newCapacity];
                System.arraycopy(elements, 0, newElements, 0,
                                 Math.min(capacity, newCapacity));
                elements = newElements;
            }
            // Initialize new elements (if applicable).
            if (initialElement != null) {
                char c = toElement(initialElement);
                for (int i = capacity; i < newCapacity; i++)
                    elements[i] = c;
            }
        }
        capacity = newCapacity;
        array = null;
        displacement = 0;
        isDisplaced = false;
        return this;
    }

    @Override
    public AbstractVector adjustArray(int newCapacity,
                                       AbstractArray displacedTo,
                                       int displacement)
    {
        capacity = newCapacity;
        array = displacedTo;
        this.displacement = displacement;
        elements = null;
        isDisplaced = true;
        return this;
    }
}
